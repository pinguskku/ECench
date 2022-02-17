commit 94106cc41ff3795b9b13044f5625c2e1089795f5
Author: Paweł Bylica <pawel.bylica@imapp.pl>
Date:   Fri Jan 23 16:45:22 2015 +0100

    JitVm code cleanups & refactoring. Some memory copies eliminated (i.e. in SHA3 calculation)

diff --git a/vm/vm_jit.go b/vm/vm_jit.go
index eaebc0749..0150a4eef 100644
--- a/vm/vm_jit.go
+++ b/vm/vm_jit.go
@@ -15,6 +15,8 @@ struct evmjit_result
 
 struct evmjit_result evmjit_run(void* _data, void* _env);
 
+// Shared library evmjit (e.g. libevmjit.so) is expected to be installed in /usr/local/lib
+// More: https://github.com/ethereum/evmjit
 #cgo LDFLAGS: -levmjit
 */
 import "C"
@@ -74,10 +76,11 @@ func hash2llvm(h []byte) i256 {
 }
 
 func llvm2hash(m *i256) []byte {
-	if len(m) != 32 {
-		panic("I don't know Go!")
-	}
-	return C.GoBytes(unsafe.Pointer(m), 32)
+	return C.GoBytes(unsafe.Pointer(m), C.int(len(m)))
+}
+
+func llvm2hashRef(m *i256) []byte {
+	return (*[1 << 30]byte)(unsafe.Pointer(m))[:len(m):len(m)]
 }
 
 func address2llvm(addr []byte) i256 {
@@ -86,6 +89,8 @@ func address2llvm(addr []byte) i256 {
 	return n
 }
 
+// bswap swap bytes of the 256-bit integer on LLVM side
+// TODO: Do not change memory on LLVM side, that can conflict with memory access optimizations
 func bswap(m *i256) *i256 {
 	for i, l := 0, len(m); i < l/2; i++ {
 		m[i], m[l-i-1] = m[l-i-1], m[i]
@@ -129,12 +134,14 @@ func llvm2big(m *i256) *big.Int {
 	return n
 }
 
-func llvm2bytes(data *byte, length uint64) []byte {
+// llvm2bytesRef creates a []byte slice that references byte buffer on LLVM side (as of that not controller by GC)
+// User must asure that referenced memory is available to Go until the data is copied or not needed any more
+func llvm2bytesRef(data *byte, length uint64) []byte {
 	if length == 0 {
 		return nil
 	}
 	if data == nil {
-		panic("llvm2bytes: nil pointer to data")
+		panic("Unexpected nil data pointer")
 	}
 	return (*[1 << 30]byte)(unsafe.Pointer(data))[:length:length]
 }
@@ -156,8 +163,10 @@ func NewJitVm(env Environment) *JitVm {
 }
 
 func (self *JitVm) Run(me, caller ContextRef, code []byte, value, gas, price *big.Int, callData []byte) (ret []byte, err error) {
+	// TODO: depth is increased but never checked by VM. VM should not know about it at all.
 	self.env.SetDepth(self.env.Depth() + 1)
 
+	// TODO: Move it to Env.Call() or sth
 	if Precompiled[string(me.Address())] != nil {
 		// if it's address of precopiled contract
 		// fallback to standard VM
@@ -165,7 +174,11 @@ func (self *JitVm) Run(me, caller ContextRef, code []byte, value, gas, price *bi
 		return stdVm.Run(me, caller, code, value, gas, price, callData)
 	}
 
-	self.me = me // FIXME: Make sure Run() is not used more than once
+	if self.me != nil {
+		panic("JitVm.Run() can be called only once per JitVm instance")
+	}
+
+	self.me = me
 	self.callerAddr = caller.Address()
 	self.price = price
 
@@ -186,7 +199,6 @@ func (self *JitVm) Run(me, caller ContextRef, code []byte, value, gas, price *bi
 	self.data.code = getDataPtr(code)
 
 	result := C.evmjit_run(unsafe.Pointer(&self.data), unsafe.Pointer(self))
-	//fmt.Printf("JIT result: %d\n", r)
 
 	if result.returnCode >= 100 {
 		err = errors.New("OOG from JIT")
@@ -198,9 +210,9 @@ func (self *JitVm) Run(me, caller ContextRef, code []byte, value, gas, price *bi
 			ret = C.GoBytes(result.returnData, C.int(result.returnDataSize))
 			C.free(result.returnData)
 		} else if result.returnCode == 2 { // SUICIDE
+			// TODO: Suicide support logic should be moved to Env to be shared by VM implementations
 			state := self.Env().State()
-			receiverAddr := llvm2hash(bswap(&self.data.elems[address]))
-			receiverAddr = trim(receiverAddr) // TODO: trim all zeros or subslice 160bits?
+			receiverAddr := llvm2hashRef(bswap(&self.data.elems[address]))
 			receiver := state.GetOrNewStateObject(receiverAddr)
 			balance := state.GetBalance(me.Address())
 			receiver.AddAmount(balance)
@@ -224,8 +236,8 @@ func (self *JitVm) Env() Environment {
 }
 
 //export env_sha3
-func env_sha3(dataPtr unsafe.Pointer, length uint64, resultPtr unsafe.Pointer) {
-	data := C.GoBytes(dataPtr, C.int(length))
+func env_sha3(dataPtr *byte, length uint64, resultPtr unsafe.Pointer) {
+	data := llvm2bytesRef(dataPtr, length)
 	hash := crypto.Sha3(data)
 	result := (*i256)(resultPtr)
 	*result = hash2llvm(hash)
@@ -300,7 +312,7 @@ func env_call(_vm unsafe.Pointer, _gas unsafe.Pointer, _receiveAddr unsafe.Point
 	if balance.Cmp(value) >= 0 {
 		receiveAddr := llvm2hash((*i256)(_receiveAddr))
 		inData := C.GoBytes(inDataPtr, C.int(inDataLen))
-		outData := llvm2bytes(outDataPtr, outDataLen)
+		outData := llvm2bytesRef(outDataPtr, outDataLen)
 		codeAddr := llvm2hash((*i256)(_codeAddr))
 		llvmGas := (*i256)(_gas)
 		gas := llvm2big(llvmGas)
