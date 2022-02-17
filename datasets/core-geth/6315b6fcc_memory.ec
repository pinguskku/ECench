commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
commit 6315b6fcc04033167c8cde0b1a55fea280258fd4
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Jul 6 11:17:09 2020 +0200

    rlp: reduce allocations for big.Int and byte array encoding (#21291)
    
    This change further improves the performance of RLP encoding by removing
    allocations for big.Int and [...]byte types. I have added a new benchmark
    that measures RLP encoding of types.Block to verify that performance is
    improved.

diff --git a/core/types/block_test.go b/core/types/block_test.go
index ff0a641e5..46ad00c6e 100644
--- a/core/types/block_test.go
+++ b/core/types/block_test.go
@@ -23,6 +23,9 @@ import (
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/common/math"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/params"
 	"github.com/ethereum/go-ethereum/rlp"
 )
 
@@ -72,10 +75,58 @@ func TestUncleHash(t *testing.T) {
 		t.Fatalf("empty uncle hash is wrong, got %x != %x", h, exp)
 	}
 }
-func BenchmarkUncleHash(b *testing.B) {
-	uncles := make([]*Header, 0)
+
+var benchBuffer = bytes.NewBuffer(make([]byte, 0, 32000))
+
+func BenchmarkEncodeBlock(b *testing.B) {
+	block := makeBenchBlock()
 	b.ResetTimer()
+
 	for i := 0; i < b.N; i++ {
-		CalcUncleHash(uncles)
+		benchBuffer.Reset()
+		if err := rlp.Encode(benchBuffer, block); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
+
+func makeBenchBlock() *Block {
+	var (
+		key, _   = crypto.GenerateKey()
+		txs      = make([]*Transaction, 70)
+		receipts = make([]*Receipt, len(txs))
+		signer   = NewEIP155Signer(params.TestChainConfig.ChainID)
+		uncles   = make([]*Header, 3)
+	)
+	header := &Header{
+		Difficulty: math.BigPow(11, 11),
+		Number:     math.BigPow(2, 9),
+		GasLimit:   12345678,
+		GasUsed:    1476322,
+		Time:       9876543,
+		Extra:      []byte("coolest block on chain"),
+	}
+	for i := range txs {
+		amount := math.BigPow(2, int64(i))
+		price := big.NewInt(300000)
+		data := make([]byte, 100)
+		tx := NewTransaction(uint64(i), common.Address{}, amount, 123457, price, data)
+		signedTx, err := SignTx(tx, signer, key)
+		if err != nil {
+			panic(err)
+		}
+		txs[i] = signedTx
+		receipts[i] = NewReceipt(make([]byte, 32), false, tx.Gas())
+	}
+	for i := range uncles {
+		uncles[i] = &Header{
+			Difficulty: math.BigPow(11, 11),
+			Number:     math.BigPow(2, 9),
+			GasLimit:   12345678,
+			GasUsed:    1476322,
+			Time:       9876543,
+			Extra:      []byte("benchmark uncle"),
+		}
 	}
+	return NewBlock(header, txs, uncles, receipts)
 }
diff --git a/rlp/encode.go b/rlp/encode.go
index af83d8421..77b591045 100644
--- a/rlp/encode.go
+++ b/rlp/encode.go
@@ -91,13 +91,6 @@ func EncodeToReader(val interface{}) (size int, r io.Reader, err error) {
 	return eb.size(), &encReader{buf: eb}, nil
 }
 
-type encbuf struct {
-	str     []byte     // string data, contains everything except list headers
-	lheads  []listhead // all list headers
-	lhsize  int        // sum of sizes of all encoded list headers
-	sizebuf []byte     // 9-byte auxiliary buffer for uint encoding
-}
-
 type listhead struct {
 	offset int // index of this header in string data
 	size   int // total size of encoded data (including list headers)
@@ -130,9 +123,20 @@ func puthead(buf []byte, smalltag, largetag byte, size uint64) int {
 	return sizesize + 1
 }
 
+type encbuf struct {
+	str      []byte        // string data, contains everything except list headers
+	lheads   []listhead    // all list headers
+	lhsize   int           // sum of sizes of all encoded list headers
+	sizebuf  [9]byte       // auxiliary buffer for uint encoding
+	bufvalue reflect.Value // used in writeByteArrayCopy
+}
+
 // encbufs are pooled.
 var encbufPool = sync.Pool{
-	New: func() interface{} { return &encbuf{sizebuf: make([]byte, 9)} },
+	New: func() interface{} {
+		var bytes []byte
+		return &encbuf{bufvalue: reflect.ValueOf(&bytes).Elem()}
+	},
 }
 
 func (w *encbuf) reset() {
@@ -160,7 +164,6 @@ func (w *encbuf) encodeStringHeader(size int) {
 	if size < 56 {
 		w.str = append(w.str, 0x80+byte(size))
 	} else {
-		// TODO: encode to w.str directly
 		sizesize := putint(w.sizebuf[1:], uint64(size))
 		w.sizebuf[0] = 0xB7 + byte(sizesize)
 		w.str = append(w.str, w.sizebuf[:sizesize+1]...)
@@ -177,6 +180,19 @@ func (w *encbuf) encodeString(b []byte) {
 	}
 }
 
+func (w *encbuf) encodeUint(i uint64) {
+	if i == 0 {
+		w.str = append(w.str, 0x80)
+	} else if i < 128 {
+		// fits single byte
+		w.str = append(w.str, byte(i))
+	} else {
+		s := putint(w.sizebuf[1:], i)
+		w.sizebuf[0] = 0x80 + byte(s)
+		w.str = append(w.str, w.sizebuf[:s+1]...)
+	}
+}
+
 // list adds a new list header to the header stack. It returns the index
 // of the header. The caller must call listEnd with this index after encoding
 // the content of the list.
@@ -229,7 +245,7 @@ func (w *encbuf) toWriter(out io.Writer) (err error) {
 			}
 		}
 		// write the header
-		enc := head.encode(w.sizebuf)
+		enc := head.encode(w.sizebuf[:])
 		if _, err = out.Write(enc); err != nil {
 			return err
 		}
@@ -295,7 +311,7 @@ func (r *encReader) next() []byte {
 			return p
 		}
 		r.lhpos++
-		return head.encode(r.buf.sizebuf)
+		return head.encode(r.buf.sizebuf[:])
 
 	case r.strpos < len(r.buf.str):
 		// String data at the end, after all list headers.
@@ -308,10 +324,7 @@ func (r *encReader) next() []byte {
 	}
 }
 
-var (
-	encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
-	big0             = big.NewInt(0)
-)
+var encoderInterface = reflect.TypeOf(new(Encoder)).Elem()
 
 // makeWriter creates a writer function for the given type.
 func makeWriter(typ reflect.Type, ts tags) (writer, error) {
@@ -336,7 +349,7 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	case kind == reflect.Slice && isByte(typ.Elem()):
 		return writeBytes, nil
 	case kind == reflect.Array && isByte(typ.Elem()):
-		return writeByteArray, nil
+		return makeByteArrayWriter(typ), nil
 	case kind == reflect.Slice || kind == reflect.Array:
 		return makeSliceWriter(typ, ts)
 	case kind == reflect.Struct:
@@ -348,28 +361,13 @@ func makeWriter(typ reflect.Type, ts tags) (writer, error) {
 	}
 }
 
-func isByte(typ reflect.Type) bool {
-	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
-}
-
 func writeRawValue(val reflect.Value, w *encbuf) error {
 	w.str = append(w.str, val.Bytes()...)
 	return nil
 }
 
 func writeUint(val reflect.Value, w *encbuf) error {
-	i := val.Uint()
-	if i == 0 {
-		w.str = append(w.str, 0x80)
-	} else if i < 128 {
-		// fits single byte
-		w.str = append(w.str, byte(i))
-	} else {
-		// TODO: encode int to w.str directly
-		s := putint(w.sizebuf[1:], i)
-		w.sizebuf[0] = 0x80 + byte(s)
-		w.str = append(w.str, w.sizebuf[:s+1]...)
-	}
+	w.encodeUint(val.Uint())
 	return nil
 }
 
@@ -396,13 +394,32 @@ func writeBigIntNoPtr(val reflect.Value, w *encbuf) error {
 	return writeBigInt(&i, w)
 }
 
+// wordBytes is the number of bytes in a big.Word
+const wordBytes = (32 << (uint64(^big.Word(0)) >> 63)) / 8
+
 func writeBigInt(i *big.Int, w *encbuf) error {
-	if cmp := i.Cmp(big0); cmp == -1 {
+	if i.Sign() == -1 {
 		return fmt.Errorf("rlp: cannot encode negative *big.Int")
-	} else if cmp == 0 {
-		w.str = append(w.str, 0x80)
-	} else {
-		w.encodeString(i.Bytes())
+	}
+	bitlen := i.BitLen()
+	if bitlen <= 64 {
+		w.encodeUint(i.Uint64())
+		return nil
+	}
+	// Integer is larger than 64 bits, encode from i.Bits().
+	// The minimal byte length is bitlen rounded up to the next
+	// multiple of 8, divided by 8.
+	length := ((bitlen + 7) & -8) >> 3
+	w.encodeStringHeader(length)
+	w.str = append(w.str, make([]byte, length)...)
+	index := length
+	buf := w.str[len(w.str)-length:]
+	for _, d := range i.Bits() {
+		for j := 0; j < wordBytes && index > 0; j++ {
+			index--
+			buf[index] = byte(d)
+			d >>= 8
+		}
 	}
 	return nil
 }
@@ -412,7 +429,52 @@ func writeBytes(val reflect.Value, w *encbuf) error {
 	return nil
 }
 
-func writeByteArray(val reflect.Value, w *encbuf) error {
+var byteType = reflect.TypeOf(byte(0))
+
+func makeByteArrayWriter(typ reflect.Type) writer {
+	length := typ.Len()
+	if length == 0 {
+		return writeLengthZeroByteArray
+	} else if length == 1 {
+		return writeLengthOneByteArray
+	}
+	if typ.Elem() != byteType {
+		return writeNamedByteArray
+	}
+	return func(val reflect.Value, w *encbuf) error {
+		writeByteArrayCopy(length, val, w)
+		return nil
+	}
+}
+
+func writeLengthZeroByteArray(val reflect.Value, w *encbuf) error {
+	w.str = append(w.str, 0x80)
+	return nil
+}
+
+func writeLengthOneByteArray(val reflect.Value, w *encbuf) error {
+	b := byte(val.Index(0).Uint())
+	if b <= 0x7f {
+		w.str = append(w.str, b)
+	} else {
+		w.str = append(w.str, 0x81, b)
+	}
+	return nil
+}
+
+// writeByteArrayCopy encodes byte arrays using reflect.Copy. This is
+// the fast path for [N]byte where N > 1.
+func writeByteArrayCopy(length int, val reflect.Value, w *encbuf) {
+	w.encodeStringHeader(length)
+	offset := len(w.str)
+	w.str = append(w.str, make([]byte, length)...)
+	w.bufvalue.SetBytes(w.str[offset:])
+	reflect.Copy(w.bufvalue, val)
+}
+
+// writeNamedByteArray encodes byte arrays with named element type.
+// This exists because reflect.Copy can't be used with such types.
+func writeNamedByteArray(val reflect.Value, w *encbuf) error {
 	if !val.CanAddr() {
 		// Slice requires the value to be addressable.
 		// Make it addressable by copying.
diff --git a/rlp/encode_test.go b/rlp/encode_test.go
index b4b9e5128..680374519 100644
--- a/rlp/encode_test.go
+++ b/rlp/encode_test.go
@@ -25,6 +25,8 @@ import (
 	"math/big"
 	"sync"
 	"testing"
+
+	"github.com/ethereum/go-ethereum/common/math"
 )
 
 type testEncoder struct {
@@ -137,16 +139,43 @@ var encTests = []encTest{
 	// negative ints are not supported
 	{val: big.NewInt(-1), error: "rlp: cannot encode negative *big.Int"},
 
-	// byte slices, strings
+	// byte arrays
+	{val: [0]byte{}, output: "80"},
+	{val: [1]byte{0}, output: "00"},
+	{val: [1]byte{1}, output: "01"},
+	{val: [1]byte{0x7F}, output: "7F"},
+	{val: [1]byte{0x80}, output: "8180"},
+	{val: [1]byte{0xFF}, output: "81FF"},
+	{val: [3]byte{1, 2, 3}, output: "83010203"},
+	{val: [57]byte{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// named byte type arrays
+	{val: [0]namedByteType{}, output: "80"},
+	{val: [1]namedByteType{0}, output: "00"},
+	{val: [1]namedByteType{1}, output: "01"},
+	{val: [1]namedByteType{0x7F}, output: "7F"},
+	{val: [1]namedByteType{0x80}, output: "8180"},
+	{val: [1]namedByteType{0xFF}, output: "81FF"},
+	{val: [3]namedByteType{1, 2, 3}, output: "83010203"},
+	{val: [57]namedByteType{1, 2, 3}, output: "B839010203000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"},
+
+	// byte slices
 	{val: []byte{}, output: "80"},
+	{val: []byte{0}, output: "00"},
 	{val: []byte{0x7E}, output: "7E"},
 	{val: []byte{0x7F}, output: "7F"},
 	{val: []byte{0x80}, output: "8180"},
 	{val: []byte{1, 2, 3}, output: "83010203"},
 
+	// named byte type slices
+	{val: []namedByteType{}, output: "80"},
+	{val: []namedByteType{0}, output: "00"},
+	{val: []namedByteType{0x7E}, output: "7E"},
+	{val: []namedByteType{0x7F}, output: "7F"},
+	{val: []namedByteType{0x80}, output: "8180"},
 	{val: []namedByteType{1, 2, 3}, output: "83010203"},
-	{val: [...]namedByteType{1, 2, 3}, output: "83010203"},
 
+	// strings
 	{val: "", output: "80"},
 	{val: "\x7E", output: "7E"},
 	{val: "\x7F", output: "7F"},
@@ -401,3 +430,36 @@ func TestEncodeToReaderReturnToPool(t *testing.T) {
 	}
 	wg.Wait()
 }
+
+var sink interface{}
+
+func BenchmarkIntsize(b *testing.B) {
+	for i := 0; i < b.N; i++ {
+		sink = intsize(0x12345678)
+	}
+}
+
+func BenchmarkPutint(b *testing.B) {
+	buf := make([]byte, 8)
+	for i := 0; i < b.N; i++ {
+		putint(buf, 0x12345678)
+		sink = buf
+	}
+}
+
+func BenchmarkEncodeBigInts(b *testing.B) {
+	ints := make([]*big.Int, 200)
+	for i := range ints {
+		ints[i] = math.BigPow(2, int64(i))
+	}
+	out := bytes.NewBuffer(make([]byte, 0, 4096))
+	b.ResetTimer()
+	b.ReportAllocs()
+
+	for i := 0; i < b.N; i++ {
+		out.Reset()
+		if err := Encode(out, ints); err != nil {
+			b.Fatal(err)
+		}
+	}
+}
diff --git a/rlp/typecache.go b/rlp/typecache.go
index e9a1e3f9e..6026e1a64 100644
--- a/rlp/typecache.go
+++ b/rlp/typecache.go
@@ -210,6 +210,10 @@ func isUint(k reflect.Kind) bool {
 	return k >= reflect.Uint && k <= reflect.Uintptr
 }
 
+func isByte(typ reflect.Type) bool {
+	return typ.Kind() == reflect.Uint8 && !typ.Implements(encoderInterface)
+}
+
 func isByteArray(typ reflect.Type) bool {
 	return (typ.Kind() == reflect.Slice || typ.Kind() == reflect.Array) && isByte(typ.Elem())
 }
