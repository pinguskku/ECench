commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
commit ac697326a6045eaa760b159e4bda37c57be61cbf
Author: Jeffrey Wilcke <geffobscura@gmail.com>
Date:   Thu Aug 6 23:06:47 2015 +0200

    core/vm: reduced big int allocations
    
    Reduced big int allocation by making stack items modifiable. Instead of
    adding items such as `common.Big0` to the stack, `new(big.Int)` is
    added instead. One must expect that any item that is added to the stack
    might change.

diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index d7605e5a2..6b7b41220 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -46,40 +46,33 @@ func opStaticJump(instr instruction, ret *big.Int, env Environment, context *Con
 
 func opAdd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Add(x, y)))
+	stack.push(U256(x.Add(x, y)))
 }
 
 func opSub(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Sub(x, y)))
+	stack.push(U256(x.Sub(x, y)))
 }
 
 func opMul(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(U256(new(big.Int).Mul(x, y)))
+	stack.push(U256(x.Mul(x, y)))
 }
 
 func opDiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) != 0 {
-		base.Div(x, y)
+		stack.push(U256(x.Div(x, y)))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	// pop result back on the stack
-	stack.push(U256(base))
 }
 
 func opSdiv(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
+		return
 	} else {
 		n := new(big.Int)
 		if new(big.Int).Mul(x, y).Cmp(common.Big0) < 0 {
@@ -88,35 +81,27 @@ func opSdiv(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Div(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Div(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opMod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
-		base.Mod(x, y)
+		stack.push(U256(x.Mod(x, y)))
 	}
-
-	U256(base)
-
-	stack.push(base)
 }
 
 func opSmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := S256(stack.pop()), S256(stack.pop())
 
 	if y.Cmp(common.Big0) == 0 {
-		base.Set(common.Big0)
+		stack.push(new(big.Int))
 	} else {
 		n := new(big.Int)
 		if x.Cmp(common.Big0) < 0 {
@@ -125,23 +110,16 @@ func opSmod(instr instruction, env Environment, context *Context, memory *Memory
 			n.SetInt64(1)
 		}
 
-		base.Mod(x.Abs(x), y.Abs(y)).Mul(base, n)
+		res := x.Mod(x.Abs(x), y.Abs(y))
+		res.Mul(res, n)
 
-		U256(base)
+		stack.push(U256(res))
 	}
-
-	stack.push(base)
 }
 
 func opExp(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	x, y := stack.pop(), stack.pop()
-
-	base.Exp(x, y, Pow256)
-
-	U256(base)
-
-	stack.push(base)
+	stack.push(U256(x.Exp(x, y, Pow256)))
 }
 
 func opSignExtend(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -149,7 +127,7 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 	if back.Cmp(big.NewInt(31)) < 0 {
 		bit := uint(back.Uint64()*8 + 7)
 		num := stack.pop()
-		mask := new(big.Int).Lsh(common.Big1, bit)
+		mask := back.Lsh(common.Big1, bit)
 		mask.Sub(mask, common.Big1)
 		if common.BitTest(num, int(bit)) {
 			num.Or(num, mask.Not(mask))
@@ -157,145 +135,116 @@ func opSignExtend(instr instruction, env Environment, context *Context, memory *
 			num.And(num, mask)
 		}
 
-		num = U256(num)
-
-		stack.push(num)
+		stack.push(U256(num))
 	}
 }
 
 func opNot(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	stack.push(U256(new(big.Int).Not(stack.pop())))
+	x := stack.pop()
+	stack.push(U256(x.Not(x)))
 }
 
 func opLt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x < y
 	if x.Cmp(y) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opGt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSlt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x < y
 	if x.Cmp(S256(y)) < 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opSgt(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := S256(stack.pop()), S256(stack.pop())
-
-	// x > y
 	if x.Cmp(y) > 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opEq(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	// x == y
 	if x.Cmp(y) == 0 {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	} else {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 	}
 }
 
 func opIszero(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x := stack.pop()
-	if x.Cmp(common.BigFalse) > 0 {
-		stack.push(common.BigFalse)
+	if x.Cmp(common.Big0) > 0 {
+		stack.push(new(big.Int))
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 	}
 }
 
 func opAnd(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).And(x, y))
+	stack.push(x.And(x, y))
 }
 func opOr(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Or(x, y))
+	stack.push(x.Or(x, y))
 }
 func opXor(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	x, y := stack.pop(), stack.pop()
-
-	stack.push(new(big.Int).Xor(x, y))
+	stack.push(x.Xor(x, y))
 }
 func opByte(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
 	th, val := stack.pop(), stack.pop()
-
 	if th.Cmp(big.NewInt(32)) < 0 {
-		byt := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
-
-		base.Set(byt)
+		byte := big.NewInt(int64(common.LeftPadBytes(val.Bytes(), 32)[th.Int64()]))
+		stack.push(byte)
 	} else {
-		base.Set(common.BigFalse)
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opAddmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		add := new(big.Int).Add(x, y)
-		base.Mod(add, z)
-
-		base = U256(base)
+		add := x.Add(x, y)
+		add.Mod(add, z)
+		stack.push(U256(add))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 func opMulmod(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
-	base := new(big.Int)
-	x := stack.pop()
-	y := stack.pop()
-	z := stack.pop()
-
+	x, y, z := stack.pop(), stack.pop(), stack.pop()
 	if z.Cmp(Zero) > 0 {
-		mul := new(big.Int).Mul(x, y)
-		base.Mod(mul, z)
-
-		U256(base)
+		mul := x.Mul(x, y)
+		mul.Mod(mul, z)
+		stack.push(U256(mul))
+	} else {
+		stack.push(new(big.Int))
 	}
-
-	stack.push(base)
 }
 
 func opSha3(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
 	offset, size := stack.pop(), stack.pop()
 	hash := crypto.Sha3(memory.Get(offset.Int64(), size.Int64()))
 
-	stack.push(common.BigD(hash))
+	stack.push(common.BytesToBig(hash))
 }
 
 func opAddress(instr instruction, env Environment, context *Context, memory *Memory, stack *stack) {
@@ -383,7 +332,7 @@ func opBlockhash(instr instruction, env Environment, context *Context, memory *M
 	if num.Cmp(n) > 0 && num.Cmp(env.BlockNumber()) < 0 {
 		stack.push(env.GetHash(num.Uint64()).Big())
 	} else {
-		stack.push(common.Big0)
+		stack.push(new(big.Int))
 	}
 }
 
@@ -497,7 +446,7 @@ func opCreate(instr instruction, env Environment, context *Context, memory *Memo
 	context.UseGas(context.Gas)
 	ret, suberr, ref := env.Create(context, input, gas, context.Price, value)
 	if suberr != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
 		// gas < len(ret) * Createinstr.dataGas == NO_CODE
@@ -535,10 +484,10 @@ func opCall(instr instruction, env Environment, context *Context, memory *Memory
 	ret, err := env.Call(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
@@ -566,10 +515,10 @@ func opCallCode(instr instruction, env Environment, context *Context, memory *Me
 	ret, err := env.CallCode(context, address, args, gas, context.Price, value)
 
 	if err != nil {
-		stack.push(common.BigFalse)
+		stack.push(new(big.Int))
 
 	} else {
-		stack.push(common.BigTrue)
+		stack.push(big.NewInt(1))
 
 		memory.Set(retOffset.Uint64(), retSize.Uint64(), ret)
 	}
diff --git a/core/vm/jit.go b/core/vm/jit.go
index c66630ae8..d5c2d7830 100644
--- a/core/vm/jit.go
+++ b/core/vm/jit.go
@@ -404,9 +404,10 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 
 		mSize, mStart := stack.data[stack.len()-2], stack.data[stack.len()-1]
 
+		add := new(big.Int)
 		gas.Add(gas, params.LogGas)
-		gas.Add(gas, new(big.Int).Mul(big.NewInt(int64(n)), params.LogTopicGas))
-		gas.Add(gas, new(big.Int).Mul(mSize, params.LogDataGas))
+		gas.Add(gas, add.Mul(big.NewInt(int64(n)), params.LogTopicGas))
+		gas.Add(gas, add.Mul(mSize, params.LogDataGas))
 
 		newMemSize = calcMemSize(mStart, mSize)
 	case EXP:
@@ -496,18 +497,20 @@ func jitCalculateGasAndSize(env Environment, context *Context, caller ContextRef
 		newMemSize.Mul(newMemSizeWords, u256(32))
 
 		if newMemSize.Cmp(u256(int64(mem.Len()))) > 0 {
+			// be careful reusing variables here when changing.
+			// The order has been optimised to reduce allocation
 			oldSize := toWordSize(big.NewInt(int64(mem.Len())))
 			pow := new(big.Int).Exp(oldSize, common.Big2, Zero)
-			linCoef := new(big.Int).Mul(oldSize, params.MemoryGas)
+			linCoef := oldSize.Mul(oldSize, params.MemoryGas)
 			quadCoef := new(big.Int).Div(pow, params.QuadCoeffDiv)
 			oldTotalFee := new(big.Int).Add(linCoef, quadCoef)
 
 			pow.Exp(newMemSizeWords, common.Big2, Zero)
-			linCoef = new(big.Int).Mul(newMemSizeWords, params.MemoryGas)
-			quadCoef = new(big.Int).Div(pow, params.QuadCoeffDiv)
-			newTotalFee := new(big.Int).Add(linCoef, quadCoef)
+			linCoef = linCoef.Mul(newMemSizeWords, params.MemoryGas)
+			quadCoef = quadCoef.Div(pow, params.QuadCoeffDiv)
+			newTotalFee := linCoef.Add(linCoef, quadCoef)
 
-			fee := new(big.Int).Sub(newTotalFee, oldTotalFee)
+			fee := newTotalFee.Sub(newTotalFee, oldTotalFee)
 			gas.Add(gas, fee)
 		}
 	}
diff --git a/core/vm/stack.go b/core/vm/stack.go
index 23c109455..009ac9e1b 100644
--- a/core/vm/stack.go
+++ b/core/vm/stack.go
@@ -21,14 +21,17 @@ import (
 	"math/big"
 )
 
-func newstack() *stack {
-	return &stack{}
-}
-
+// stack is an object for basic stack operations. Items popped to the stack are
+// expected to be changed and modified. stack does not take care of adding newly
+// initialised objects.
 type stack struct {
 	data []*big.Int
 }
 
+func newstack() *stack {
+	return &stack{}
+}
+
 func (st *stack) Data() []*big.Int {
 	return st.data
 }
diff --git a/tests/vm_test.go b/tests/vm_test.go
index 6b6b179fd..afa1424d5 100644
--- a/tests/vm_test.go
+++ b/tests/vm_test.go
@@ -30,7 +30,7 @@ func BenchmarkVmAckermann32Tests(b *testing.B) {
 
 func BenchmarkVmFibonacci16Tests(b *testing.B) {
 	fn := filepath.Join(vmTestDir, "vmPerformanceTest.json")
-	if err := BenchVmTest(fn, bconf{"fibonacci16", true, true}, b); err != nil {
+	if err := BenchVmTest(fn, bconf{"fibonacci16", true, false}, b); err != nil {
 		b.Error(err)
 	}
 }
