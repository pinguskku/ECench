commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -89commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
commit b566cfdffdc51d5dcde571377d709a5519a24f0d
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon Nov 4 10:31:10 2019 +0100

    core/evm: avoid copying memory for input in calls (#20177)
    
    * core/evm, contracts: avoid copying memory for input in calls + make ecrecover not modify input buffer
    
    * core/vm: optimize mstore a bit
    
    * core/vm: change Get -> GetCopy in vm memory access

diff --git a/core/vm/contracts.go b/core/vm/contracts.go
index 875054f89..9b0ba09ed 100644
--- a/core/vm/contracts.go
+++ b/core/vm/contracts.go
@@ -106,8 +106,13 @@ func (c *ecrecover) Run(input []byte) ([]byte, error) {
 	if !allZero(input[32:63]) || !crypto.ValidateSignatureValues(v, r, s, false) {
 		return nil, nil
 	}
+	// We must make sure not to modify the 'input', so placing the 'v' along with
+	// the signature needs to be done on a new allocation
+	sig := make([]byte, 65)
+	copy(sig, input[64:128])
+	sig[64] = v
 	// v needs to be at the end for libsecp256k1
-	pubKey, err := crypto.Ecrecover(input[:32], append(input[64:128], v))
+	pubKey, err := crypto.Ecrecover(input[:32], sig)
 	// make sure the public key is a valid one
 	if err != nil {
 		return nil, nil
diff --git a/core/vm/contracts_test.go b/core/vm/contracts_test.go
index ae95b4462..b4a0c07dc 100644
--- a/core/vm/contracts_test.go
+++ b/core/vm/contracts_test.go
@@ -17,6 +17,7 @@
 package vm
 
 import (
+	"bytes"
 	"fmt"
 	"math/big"
 	"reflect"
@@ -409,6 +410,11 @@ func testPrecompiled(addr string, test precompiledTest, t *testing.T) {
 		} else if common.Bytes2Hex(res) != test.expected {
 			t.Errorf("Expected %v, got %v", test.expected, common.Bytes2Hex(res))
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -423,6 +429,11 @@ func testPrecompiledFailure(addr string, test precompiledFailureTest, t *testing
 		if !reflect.DeepEqual(err, test.expectedError) {
 			t.Errorf("Expected error [%v], got [%v]", test.expectedError, err)
 		}
+		// Verify that the precompile did not touch the input buffer
+		exp := common.Hex2Bytes(test.input)
+		if !bytes.Equal(in, exp) {
+			t.Errorf("Precompiled %v modified input data", addr)
+		}
 	})
 }
 
@@ -574,3 +585,55 @@ func TestPrecompileBlake2FMalformedInput(t *testing.T) {
 		testPrecompiledFailure("09", test, t)
 	}
 }
+
+// EcRecover test vectors
+var ecRecoverTests = []precompiledTest{
+	{
+		input: "a8b53bdf3306a35a7103ab5504a0c9b492295564b6202b1942a84ef300107281" +
+			"000000000000000000000000000000000000000000000000000000000000001b" +
+			"3078356531653033663533636531386237373263636230303933666637316633" +
+			"6635336635633735623734646362333161383561613862383839326234653862" +
+			"1122334455667788991011121314151617181920212223242526272829303132",
+		expected: "",
+		name:     "CallEcrecoverUnrecoverableKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "000000000000000000000000a94f5374fce5edbc8e2a8697c15331677e6ebf0b",
+		name:     "ValidKey",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"100000000000000000000000000000000000000000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-1",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000001c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-2",
+	},
+	{
+		input: "18c547e4f7b0f325ad1e56f57e26c745b09a3e503d86e00e5255ff7f715d3d1c" +
+			"000000000000000000000000000000000000001000000000000000000000011c" +
+			"73b1693892219d736caba55bdb67216e485557ea6b6af75f37096c9aa6a5a75f" +
+			"eeb940b1d03b21e36b0e47e79769f095fe2ab855bd91e3a38756b7d75a9c4549",
+		expected: "",
+		name:     "InvalidHighV-bits-3",
+	},
+}
+
+func TestPrecompiledEcrecover(t *testing.T) {
+	for _, test := range ecRecoverTests {
+		testPrecompiled("01", test, t)
+	}
+
+}
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 7b6909c92..d65664b67 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -384,7 +384,7 @@ func opSAR(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 
 func opSha3(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
 	offset, size := stack.pop(), stack.pop()
-	data := memory.Get(offset.Int64(), size.Int64())
+	data := memory.GetPtr(offset.Int64(), size.Int64())
 
 	if interpreter.hasher == nil {
 		interpreter.hasher = sha3.NewLegacyKeccak256().(keccakState)
@@ -602,11 +602,9 @@ func opPop(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *
 }
 
 func opMload(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	offset := stack.pop()
-	val := interpreter.intPool.get().SetBytes(memory.Get(offset.Int64(), 32))
-	stack.push(val)
-
-	interpreter.intPool.put(offset)
+	v := stack.peek()
+	offset := v.Int64()
+	v.SetBytes(memory.GetPtr(offset, 32))
 	return nil, nil
 }
 
@@ -691,7 +689,7 @@ func opCreate(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memor
 	var (
 		value        = stack.pop()
 		offset, size = stack.pop(), stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 	if interpreter.evm.chainRules.IsEIP150 {
@@ -725,7 +723,7 @@ func opCreate2(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memo
 		endowment    = stack.pop()
 		offset, size = stack.pop(), stack.pop()
 		salt         = stack.pop()
-		input        = memory.Get(offset.Int64(), size.Int64())
+		input        = memory.GetCopy(offset.Int64(), size.Int64())
 		gas          = contract.Gas
 	)
 
@@ -757,7 +755,7 @@ func opCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, memory
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get the arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -786,7 +784,7 @@ func opCallCode(pc *uint64, interpreter *EVMInterpreter, contract *Contract, mem
 	toAddr := common.BigToAddress(addr)
 	value = math.U256(value)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	if value.Sign() != 0 {
 		gas += params.CallStipend
@@ -814,7 +812,7 @@ func opDelegateCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract,
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.DelegateCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -839,7 +837,7 @@ func opStaticCall(pc *uint64, interpreter *EVMInterpreter, contract *Contract, m
 	addr, inOffset, inSize, retOffset, retSize := stack.pop(), stack.pop(), stack.pop(), stack.pop(), stack.pop()
 	toAddr := common.BigToAddress(addr)
 	// Get arguments from the memory.
-	args := memory.Get(inOffset.Int64(), inSize.Int64())
+	args := memory.GetPtr(inOffset.Int64(), inSize.Int64())
 
 	ret, returnGas, err := interpreter.evm.StaticCall(contract, toAddr, args, gas)
 	if err != nil {
@@ -895,7 +893,7 @@ func makeLog(size int) executionFunc {
 			topics[i] = common.BigToHash(stack.pop())
 		}
 
-		d := memory.Get(mStart.Int64(), mSize.Int64())
+		d := memory.GetCopy(mStart.Int64(), mSize.Int64())
 		interpreter.evm.StateDB.AddLog(&types.Log{
 			Address: contract.Address(),
 			Topics:  topics,
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
index 50d0a9dda..b12df3905 100644
--- a/core/vm/instructions_test.go
+++ b/core/vm/instructions_test.go
@@ -509,12 +509,12 @@ func TestOpMstore(t *testing.T) {
 	v := "abcdef00000000000000abba000000000deaf000000c0de00100000000133700"
 	stack.pushN(new(big.Int).SetBytes(common.Hex2Bytes(v)), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if got := common.Bytes2Hex(mem.Get(0, 32)); got != v {
+	if got := common.Bytes2Hex(mem.GetCopy(0, 32)); got != v {
 		t.Fatalf("Mstore fail, got %v, expected %v", got, v)
 	}
 	stack.pushN(big.NewInt(0x1), big.NewInt(0))
 	opMstore(&pc, evmInterpreter, nil, mem, stack)
-	if common.Bytes2Hex(mem.Get(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
+	if common.Bytes2Hex(mem.GetCopy(0, 32)) != "0000000000000000000000000000000000000000000000000000000000000001" {
 		t.Fatalf("Mstore failed to overwrite previous value")
 	}
 	poolOfIntPools.put(evmInterpreter.intPool)
diff --git a/core/vm/memory.go b/core/vm/memory.go
index 7e6f0eb94..496a4024b 100644
--- a/core/vm/memory.go
+++ b/core/vm/memory.go
@@ -70,7 +70,7 @@ func (m *Memory) Resize(size uint64) {
 }
 
 // Get returns offset + size as a new slice
-func (m *Memory) Get(offset, size int64) (cpy []byte) {
+func (m *Memory) GetCopy(offset, size int64) (cpy []byte) {
 	if size == 0 {
 		return nil
 	}
diff --git a/eth/tracers/tracer.go b/eth/tracers/tracer.go
index c0729fb1d..724c5443a 100644
--- a/eth/tracers/tracer.go
+++ b/eth/tracers/tracer.go
@@ -99,7 +99,7 @@ func (mw *memoryWrapper) slice(begin, end int64) []byte {
 		log.Warn("Tracer accessed out of bound memory", "available", mw.memory.Len(), "offset", begin, "size", end-begin)
 		return nil
 	}
-	return mw.memory.Get(begin, end-begin)
+	return mw.memory.GetCopy(begin, end-begin)
 }
 
 // getUint returns the 32 bytes at the specified address interpreted as a uint.
