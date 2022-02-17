commit 155795be99f232a583696b21ce294b77f0bdffc1
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Dec 14 11:30:20 2021 +0100

    core/vm: avoid memory expansion check for trivial ops (#24048)

diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index 53f4acc84..1660e3ce0 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -181,62 +181,56 @@ func (in *EVMInterpreter) Run(contract *Contract, input []byte, readOnly bool) (
 			// Capture pre-execution values for tracing.
 			logged, pcCopy, gasCopy = false, pc, contract.Gas
 		}
-
 		// Get the operation from the jump table and validate the stack to ensure there are
 		// enough stack items available to perform the operation.
 		op = contract.GetOp(pc)
 		operation := in.cfg.JumpTable[op]
+		cost = operation.constantGas // For tracing
 		// Validate stack
 		if sLen := stack.len(); sLen < operation.minStack {
 			return nil, &ErrStackUnderflow{stackLen: sLen, required: operation.minStack}
 		} else if sLen > operation.maxStack {
 			return nil, &ErrStackOverflow{stackLen: sLen, limit: operation.maxStack}
 		}
-		// Static portion of gas
-		cost = operation.constantGas // For tracing
-		if !contract.UseGas(operation.constantGas) {
+		if !contract.UseGas(cost) {
 			return nil, ErrOutOfGas
 		}
-
-		var memorySize uint64
-		// calculate the new memory size and expand the memory to fit
-		// the operation
-		// Memory check needs to be done prior to evaluating the dynamic gas portion,
-		// to detect calculation overflows
-		if operation.memorySize != nil {
-			memSize, overflow := operation.memorySize(stack)
-			if overflow {
-				return nil, ErrGasUintOverflow
-			}
-			// memory is expanded in words of 32 bytes. Gas
-			// is also calculated in words.
-			if memorySize, overflow = math.SafeMul(toWordSize(memSize), 32); overflow {
-				return nil, ErrGasUintOverflow
-			}
-		}
-		// Dynamic portion of gas
-		// consume the gas and return an error if not enough gas is available.
-		// cost is explicitly set so that the capture state defer method can get the proper cost
 		if operation.dynamicGas != nil {
+			// All ops with a dynamic memory usage also has a dynamic gas cost.
+			var memorySize uint64
+			// calculate the new memory size and expand the memory to fit
+			// the operation
+			// Memory check needs to be done prior to evaluating the dynamic gas portion,
+			// to detect calculation overflows
+			if operation.memorySize != nil {
+				memSize, overflow := operation.memorySize(stack)
+				if overflow {
+					return nil, ErrGasUintOverflow
+				}
+				// memory is expanded in words of 32 bytes. Gas
+				// is also calculated in words.
+				if memorySize, overflow = math.SafeMul(toWordSize(memSize), 32); overflow {
+					return nil, ErrGasUintOverflow
+				}
+			}
+			// Consume the gas and return an error if not enough gas is available.
+			// cost is explicitly set so that the capture state defer method can get the proper cost
 			var dynamicCost uint64
 			dynamicCost, err = operation.dynamicGas(in.evm, contract, stack, mem, memorySize)
-			cost += dynamicCost // total cost, for debug tracing
+			cost += dynamicCost // for tracing
 			if err != nil || !contract.UseGas(dynamicCost) {
 				return nil, ErrOutOfGas
 			}
+			if memorySize > 0 {
+				mem.Resize(memorySize)
+			}
 		}
-		if memorySize > 0 {
-			mem.Resize(memorySize)
-		}
-
 		if in.cfg.Debug {
 			in.cfg.Tracer.CaptureState(pc, op, gasCopy, cost, callContext, in.returnData, in.evm.depth, err)
 			logged = true
 		}
-
 		// execute the operation
 		res, err = operation.execute(&pc, in, callContext)
-
 		if err != nil {
 			break
 		}
diff --git a/core/vm/jump_table.go b/core/vm/jump_table.go
index bb559b594..6dea5d81f 100644
--- a/core/vm/jump_table.go
+++ b/core/vm/jump_table.go
@@ -17,6 +17,8 @@
 package vm
 
 import (
+	"fmt"
+
 	"github.com/ethereum/go-ethereum/params"
 )
 
@@ -57,13 +59,31 @@ var (
 // JumpTable contains the EVM opcodes supported at a given fork.
 type JumpTable [256]*operation
 
+func validate(jt JumpTable) JumpTable {
+	for i, op := range jt {
+		if op == nil {
+			panic(fmt.Sprintf("op 0x%x is not set", i))
+		}
+		// The interpreter has an assumption that if the memorySize function is
+		// set, then the dynamicGas function is also set. This is a somewhat
+		// arbitrary assumption, and can be removed if we need to -- but it
+		// allows us to avoid a condition check. As long as we have that assumption
+		// in there, this little sanity check prevents us from merging in a
+		// change which violates it.
+		if op.memorySize != nil && op.dynamicGas == nil {
+			panic(fmt.Sprintf("op %v has dynamic memory but not dynamic gas", OpCode(i).String()))
+		}
+	}
+	return jt
+}
+
 // newLondonInstructionSet returns the frontier, homestead, byzantium,
 // contantinople, istanbul, petersburg, berlin and london instructions.
 func newLondonInstructionSet() JumpTable {
 	instructionSet := newBerlinInstructionSet()
 	enable3529(&instructionSet) // EIP-3529: Reduction in refunds https://eips.ethereum.org/EIPS/eip-3529
 	enable3198(&instructionSet) // Base fee opcode https://eips.ethereum.org/EIPS/eip-3198
-	return instructionSet
+	return validate(instructionSet)
 }
 
 // newBerlinInstructionSet returns the frontier, homestead, byzantium,
@@ -71,7 +91,7 @@ func newLondonInstructionSet() JumpTable {
 func newBerlinInstructionSet() JumpTable {
 	instructionSet := newIstanbulInstructionSet()
 	enable2929(&instructionSet) // Access lists for trie accesses https://eips.ethereum.org/EIPS/eip-2929
-	return instructionSet
+	return validate(instructionSet)
 }
 
 // newIstanbulInstructionSet returns the frontier, homestead, byzantium,
@@ -83,7 +103,7 @@ func newIstanbulInstructionSet() JumpTable {
 	enable1884(&instructionSet) // Reprice reader opcodes - https://eips.ethereum.org/EIPS/eip-1884
 	enable2200(&instructionSet) // Net metered SSTORE - https://eips.ethereum.org/EIPS/eip-2200
 
-	return instructionSet
+	return validate(instructionSet)
 }
 
 // newConstantinopleInstructionSet returns the frontier, homestead,
@@ -122,7 +142,7 @@ func newConstantinopleInstructionSet() JumpTable {
 		maxStack:    maxStack(4, 1),
 		memorySize:  memoryCreate2,
 	}
-	return instructionSet
+	return validate(instructionSet)
 }
 
 // newByzantiumInstructionSet returns the frontier, homestead and
@@ -158,14 +178,14 @@ func newByzantiumInstructionSet() JumpTable {
 		maxStack:   maxStack(2, 0),
 		memorySize: memoryRevert,
 	}
-	return instructionSet
+	return validate(instructionSet)
 }
 
 // EIP 158 a.k.a Spurious Dragon
 func newSpuriousDragonInstructionSet() JumpTable {
 	instructionSet := newTangerineWhistleInstructionSet()
 	instructionSet[EXP].dynamicGas = gasExpEIP158
-	return instructionSet
+	return validate(instructionSet)
 
 }
 
@@ -179,7 +199,7 @@ func newTangerineWhistleInstructionSet() JumpTable {
 	instructionSet[CALL].constantGas = params.CallGasEIP150
 	instructionSet[CALLCODE].constantGas = params.CallGasEIP150
 	instructionSet[DELEGATECALL].constantGas = params.CallGasEIP150
-	return instructionSet
+	return validate(instructionSet)
 }
 
 // newHomesteadInstructionSet returns the frontier and homestead
@@ -194,7 +214,7 @@ func newHomesteadInstructionSet() JumpTable {
 		maxStack:    maxStack(6, 1),
 		memorySize:  memoryDelegateCall,
 	}
-	return instructionSet
+	return validate(instructionSet)
 }
 
 // newFrontierInstructionSet returns the frontier instructions
@@ -1010,5 +1030,5 @@ func newFrontierInstructionSet() JumpTable {
 		}
 	}
 
-	return tbl
+	return validate(tbl)
 }
