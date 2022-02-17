commit ea2718c9462ae351baab5eaa05a7e1ef9dc916fa
Author: Felix Lange <fjl@twurst.com>
Date:   Fri May 29 14:40:45 2015 +0200

    core/vm: improve JUMPDEST analysis
    
    * JUMPDEST analysis is faster because less type conversions are performed.
    * The map of JUMPDEST locations is now created lazily at the first JUMP.
    * The result of the analysis is kept around for recursive invocations
      through CALL/CALLCODE.
    
    Fixes #1147

diff --git a/core/vm/analysis.go b/core/vm/analysis.go
index 264d55cb9..a7aa8da39 100644
--- a/core/vm/analysis.go
+++ b/core/vm/analysis.go
@@ -3,34 +3,45 @@ package vm
 import (
 	"math/big"
 
-	"gopkg.in/fatih/set.v0"
+	"github.com/ethereum/go-ethereum/common"
 )
 
-type destinations struct {
-	set *set.Set
-}
+var bigMaxUint64 = new(big.Int).SetUint64(^uint64(0))
 
-func (d *destinations) Has(dest *big.Int) bool {
-	return d.set.Has(string(dest.Bytes()))
-}
+// destinations stores one map per contract (keyed by hash of code).
+// The maps contain an entry for each location of a JUMPDEST
+// instruction.
+type destinations map[common.Hash]map[uint64]struct{}
 
-func (d *destinations) Add(dest *big.Int) {
-	d.set.Add(string(dest.Bytes()))
+// has checks whether code has a JUMPDEST at dest.
+func (d destinations) has(codehash common.Hash, code []byte, dest *big.Int) bool {
+	// PC cannot go beyond len(code) and certainly can't be bigger than 64bits.
+	// Don't bother checking for JUMPDEST in that case.
+	if dest.Cmp(bigMaxUint64) > 0 {
+		return false
+	}
+	m, analysed := d[codehash]
+	if !analysed {
+		m = jumpdests(code)
+		d[codehash] = m
+	}
+	_, ok := m[dest.Uint64()]
+	return ok
 }
 
-func analyseJumpDests(code []byte) (dests *destinations) {
-	dests = &destinations{set.New()}
-
+// jumpdests creates a map that contains an entry for each
+// PC location that is a JUMPDEST instruction.
+func jumpdests(code []byte) map[uint64]struct{} {
+	m := make(map[uint64]struct{})
 	for pc := uint64(0); pc < uint64(len(code)); pc++ {
 		var op OpCode = OpCode(code[pc])
 		switch op {
 		case PUSH1, PUSH2, PUSH3, PUSH4, PUSH5, PUSH6, PUSH7, PUSH8, PUSH9, PUSH10, PUSH11, PUSH12, PUSH13, PUSH14, PUSH15, PUSH16, PUSH17, PUSH18, PUSH19, PUSH20, PUSH21, PUSH22, PUSH23, PUSH24, PUSH25, PUSH26, PUSH27, PUSH28, PUSH29, PUSH30, PUSH31, PUSH32:
 			a := uint64(op) - uint64(PUSH1) + 1
-
 			pc += a
 		case JUMPDEST:
-			dests.Add(big.NewInt(int64(pc)))
+			m[pc] = struct{}{}
 		}
 	}
-	return
+	return m
 }
diff --git a/core/vm/context.go b/core/vm/context.go
index 29bb9f74e..de03f84f0 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -16,6 +16,8 @@ type Context struct {
 	caller ContextRef
 	self   ContextRef
 
+	jumpdests destinations // result of JUMPDEST analysis.
+
 	Code     []byte
 	CodeAddr *common.Address
 
@@ -24,10 +26,17 @@ type Context struct {
 	Args []byte
 }
 
-// Create a new context for the given data items
+// Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
+
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
 	c.Gas = gas //new(big.Int).Set(gas)
diff --git a/core/vm/vm.go b/core/vm/vm.go
index 6db99bdcc..0d8facbb6 100644
--- a/core/vm/vm.go
+++ b/core/vm/vm.go
@@ -72,17 +72,16 @@ func (self *Vm) Run(context *Context, callData []byte) (ret []byte, err error) {
 	}
 
 	var (
-		op OpCode
-
-		destinations = analyseJumpDests(context.Code)
-		mem          = NewMemory()
-		stack        = newStack()
-		pc           = new(big.Int)
-		statedb      = self.env.State()
+		op       OpCode
+		codehash = crypto.Sha3Hash(code)
+		mem      = NewMemory()
+		stack    = newStack()
+		pc       = new(big.Int)
+		statedb  = self.env.State()
 
 		jump = func(from *big.Int, to *big.Int) error {
-			nop := context.GetOp(to)
-			if !destinations.Has(to) {
+			if !context.jumpdests.has(codehash, code, to) {
+				nop := context.GetOp(to)
 				return fmt.Errorf("invalid jump destination (%v) %v", nop, to)
 			}
 
