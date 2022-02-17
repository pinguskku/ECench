commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
commit 3285a0fda37207ca1b79ac28e2c12c6f5efff89b
Author: Martin Holst Swende <martin@swende.se>
Date:   Sun May 28 23:39:33 2017 +0200

    core/vm, common/math: Add fast getByte for bigints, improve opByte

diff --git a/common/math/big.go b/common/math/big.go
index fd0174b36..48ad90216 100644
--- a/common/math/big.go
+++ b/common/math/big.go
@@ -130,6 +130,34 @@ func PaddedBigBytes(bigint *big.Int, n int) []byte {
 	return ret
 }
 
+// LittleEndianByteAt returns the byte at position n,
+// if bigint is considered little-endian.
+// So n==0 gives the least significant byte
+func LittleEndianByteAt(bigint *big.Int, n int) byte {
+	words := bigint.Bits()
+	// Check word-bucket the byte will reside in
+	i := n / wordBytes
+	if i >= len(words) {
+		return byte(0)
+	}
+	word := words[i]
+	// Offset of the byte
+	shift := 8 * uint(n%wordBytes)
+
+	return byte(word >> shift)
+}
+
+// BigEndian32ByteAt returns the byte at position n,
+// if bigint is considered big-endian.
+// So n==0 gives the most significant byte
+// WARNING: Only works for bigints in 32-byte range
+func BigEndian32ByteAt(bigint *big.Int, n int) byte {
+	if n > 31 {
+		return byte(0)
+	}
+	return LittleEndianByteAt(bigint, 31-n)
+}
+
 // ReadBits encodes the absolute value of bigint as big-endian bytes. Callers must ensure
 // that buf has enough space. If buf is too short the result will be incomplete.
 func ReadBits(bigint *big.Int, buf []byte) {
diff --git a/common/math/big_test.go b/common/math/big_test.go
index e789bd18e..d4de7b8c3 100644
--- a/common/math/big_test.go
+++ b/common/math/big_test.go
@@ -21,6 +21,8 @@ import (
 	"encoding/hex"
 	"math/big"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
 )
 
 func TestHexOrDecimal256(t *testing.T) {
@@ -133,8 +135,40 @@ func TestPaddedBigBytes(t *testing.T) {
 	}
 }
 
-func BenchmarkPaddedBigBytes(b *testing.B) {
+func BenchmarkPaddedBigBytesLargePadding(b *testing.B) {
 	bigint := MustParseBig256("123456789123456789123456789123456789")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 200)
+	}
+}
+func BenchmarkPaddedBigBytesSmallPadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 5)
+	}
+}
+
+func BenchmarkPaddedBigBytesSmallOnePadding(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		PaddedBigBytes(bigint, 32)
+	}
+}
+func BenchmarkByteAtBrandNew(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAt(b *testing.B) {
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
+	for i := 0; i < b.N; i++ {
+		BigEndian32ByteAt(bigint, 15)
+	}
+}
+func BenchmarkByteAtOld(b *testing.B) {
+
+	bigint := MustParseBig256("0x18F8F8F1000111000110011100222004330052300000000000000000FEFCF3CC")
 	for i := 0; i < b.N; i++ {
 		PaddedBigBytes(bigint, 32)
 	}
@@ -173,7 +207,64 @@ func TestU256(t *testing.T) {
 		}
 	}
 }
+func TestLittleEndianByteAt(t *testing.T) {
+
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		//{"1", 0, 0x01},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x20},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := LittleEndianByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
+func TestBigEndianByteAt(t *testing.T) {
 
+	tests := []struct {
+		x   string
+		y   int
+		exp byte
+	}{
+		{"0", 0, 0x00},
+		{"1", 1, 0x00},
+		{"0", 1, 0x00},
+		{"1", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 0, 0x00},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 1, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 31, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 32, 0x00},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, 0xAB},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, 0xCD},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, 0x00},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, 0xCD},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, 0x30},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, 0x20},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, 0x0},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFF, 0x0},
+	}
+	for _, test := range tests {
+		v := new(big.Int).SetBytes(common.Hex2Bytes(test.x))
+		actual := BigEndian32ByteAt(v, test.y)
+		if actual != test.exp {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.x, test.y, test.exp, actual)
+		}
+
+	}
+}
 func TestS256(t *testing.T) {
 	tests := []struct{ x, y *big.Int }{
 		{x: big.NewInt(0), y: big.NewInt(0)},
diff --git a/core/vm/instructions.go b/core/vm/instructions.go
index 42f1781d8..bcaf18e8a 100644
--- a/core/vm/instructions.go
+++ b/core/vm/instructions.go
@@ -256,15 +256,14 @@ func opXor(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stac
 }
 
 func opByte(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
-	th, val := stack.pop(), stack.pop()
-	if th.Cmp(big.NewInt(32)) < 0 {
-		byte := evm.interpreter.intPool.get().SetInt64(int64(math.PaddedBigBytes(val, 32)[th.Int64()]))
-		stack.push(byte)
+	th, val := stack.pop(), stack.peek()
+	if th.Cmp(common.Big32) < 0 {
+		b := math.BigEndian32ByteAt(val, int(th.Int64()))
+		val.SetInt64(int64(b))
 	} else {
-		stack.push(new(big.Int))
+		val.SetUint64(0)
 	}
-
-	evm.interpreter.intPool.put(th, val)
+	evm.interpreter.intPool.put(th)
 	return nil, nil
 }
 func opAddmod(pc *uint64, evm *EVM, contract *Contract, memory *Memory, stack *Stack) ([]byte, error) {
diff --git a/core/vm/instructions_test.go b/core/vm/instructions_test.go
new file mode 100644
index 000000000..50264bc3e
--- /dev/null
+++ b/core/vm/instructions_test.go
@@ -0,0 +1,43 @@
+package vm
+
+import (
+	"math/big"
+	"testing"
+
+	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/params"
+)
+
+func TestByteOp(t *testing.T) {
+
+	var (
+		env   = NewEVM(Context{}, nil, params.TestChainConfig, Config{EnableJit: false, ForceJit: false})
+		stack = newstack()
+	)
+	tests := []struct {
+		v        string
+		th       uint64
+		expected *big.Int
+	}{
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 0, big.NewInt(0xAB)},
+		{"ABCDEF0908070605040302010000000000000000000000000000000000000000", 1, big.NewInt(0xCD)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 0, big.NewInt(0x00)},
+		{"00CDEF090807060504030201ffffffffffffffffffffffffffffffffffffffff", 1, big.NewInt(0xCD)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 31, big.NewInt(0x30)},
+		{"0000000000000000000000000000000000000000000000000000000000102030", 30, big.NewInt(0x20)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 32, big.NewInt(0x0)},
+		{"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 0xFFFFFFFFFFFFFFFF, big.NewInt(0x0)},
+	}
+	pc := uint64(0)
+	for _, test := range tests {
+		val := new(big.Int).SetBytes(common.Hex2Bytes(test.v))
+		th := new(big.Int).SetUint64(test.th)
+		stack.push(val)
+		stack.push(th)
+		opByte(&pc, env, nil, nil, stack)
+		actual := stack.pop()
+		if actual.Cmp(test.expected) != 0 {
+			t.Fatalf("Expected  [%v] %v:th byte to be %v, was %v.", test.v, test.th, test.expected, actual)
+		}
+	}
+}
