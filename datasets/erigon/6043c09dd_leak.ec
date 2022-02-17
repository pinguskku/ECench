commit 6043c09ddf2762f582cbc7168d37d6b1e29543e8
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Tue Jul 14 08:56:47 2020 +0700

    Replace global buff pool by local, because of buffer leaks to larger pools (#739)

diff --git a/cmd/rpcdaemon/commands/state_reader.go b/cmd/rpcdaemon/commands/state_reader.go
index 73252ee9c..d589c201a 100644
--- a/cmd/rpcdaemon/commands/state_reader.go
+++ b/cmd/rpcdaemon/commands/state_reader.go
@@ -225,9 +225,9 @@ func (r *StateReader) ForEachStorage(addr common.Address, start []byte, cb func(
 		item := i.(*storageItem)
 		if !item.value.IsZero() {
 			h.Sha.Reset()
-			//nolint:checkerr
+			//nolint:errcheck
 			h.Sha.Write(item.key[:])
-			//nolint:checkerr
+			//nolint:errcheck
 			h.Sha.Read(item.seckey[:])
 			cb(item.key, item.seckey, item.value)
 			results++
diff --git a/common/changeset/account_changeset_utils.go b/common/changeset/account_changeset_utils.go
index dfebe4fc0..dc84fe9fc 100644
--- a/common/changeset/account_changeset_utils.go
+++ b/common/changeset/account_changeset_utils.go
@@ -7,7 +7,6 @@ import (
 	"sort"
 
 	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/common/pool"
 )
 
 // walkAccountChangeSet iterates the account bytes with the keys of provided size
@@ -158,9 +157,7 @@ uint32 integers are serialized as big-endian.
 */
 func encodeAccounts(s *ChangeSet) ([]byte, error) {
 	sort.Sort(s)
-	buf := pool.GetBuffer(1 << 16)
-	buf.Reset()
-	defer pool.PutBuffer(buf)
+	buf := new(bytes.Buffer)
 	intArr := make([]byte, 4)
 	n := s.Len()
 	binary.BigEndian.PutUint32(intArr, uint32(n))
@@ -193,5 +190,5 @@ func encodeAccounts(s *ChangeSet) ([]byte, error) {
 		}
 	}
 
-	return common.CopyBytes(buf.Bytes()), nil
+	return buf.Bytes(), nil
 }
diff --git a/common/changeset/storage_changeset_utils.go b/common/changeset/storage_changeset_utils.go
index b94b3f703..9d95ad1cb 100644
--- a/common/changeset/storage_changeset_utils.go
+++ b/common/changeset/storage_changeset_utils.go
@@ -7,7 +7,6 @@ import (
 	"sort"
 
 	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/common/pool"
 )
 
 /**
@@ -37,9 +36,7 @@ numOfUint32Values uint16
 func encodeStorage(s *ChangeSet, keyPrefixLen uint32) ([]byte, error) {
 	sort.Sort(s)
 	var err error
-	buf := pool.GetBuffer(1 << 16)
-	buf.Reset()
-	defer pool.PutBuffer(buf)
+	buf := new(bytes.Buffer)
 	uint16Arr := make([]byte, 2)
 	uint32Arr := make([]byte, 4)
 	numOfElements := s.Len()
@@ -179,7 +176,7 @@ func encodeStorage(s *ChangeSet, keyPrefixLen uint32) ([]byte, error) {
 		}
 	}
 
-	return common.CopyBytes(buf.Bytes()), nil
+	return buf.Bytes(), nil
 }
 
 // decodeStorage decodes a stream of bytes to a storage changeset using
diff --git a/common/etl/buffers.go b/common/etl/buffers.go
index dca9b1bfe..6aa7f0808 100644
--- a/common/etl/buffers.go
+++ b/common/etl/buffers.go
@@ -114,14 +114,14 @@ type appendSortableBuffer struct {
 }
 
 func (b *appendSortableBuffer) Put(k, v []byte) {
-	stored, ok := b.entries[string(k)]
+	ks := string(k)
+	stored, ok := b.entries[ks]
 	if !ok {
 		b.size += len(k)
-		k = common.CopyBytes(k)
 	}
 	b.size += len(v)
 	stored = append(stored, v...)
-	b.entries[string(k)] = stored
+	b.entries[ks] = stored
 }
 
 func (b *appendSortableBuffer) Size() int {
@@ -179,7 +179,8 @@ type oldestEntrySortableBuffer struct {
 }
 
 func (b *oldestEntrySortableBuffer) Put(k, v []byte) {
-	_, ok := b.entries[string(k)]
+	ks := string(k)
+	_, ok := b.entries[ks]
 	if ok {
 		// if we already had this entry, we are going to keep it and ignore new value
 		return
@@ -187,11 +188,10 @@ func (b *oldestEntrySortableBuffer) Put(k, v []byte) {
 
 	b.size += len(k)
 	b.size += len(v)
-	k = common.CopyBytes(k)
 	if v != nil {
 		v = common.CopyBytes(v)
 	}
-	b.entries[string(k)] = v
+	b.entries[ks] = v
 }
 
 func (b *oldestEntrySortableBuffer) Size() int {
diff --git a/common/etl/dataprovider.go b/common/etl/dataprovider.go
index bfdd079b7..c52eb5965 100644
--- a/common/etl/dataprovider.go
+++ b/common/etl/dataprovider.go
@@ -40,6 +40,17 @@ func FlushToDisk(encoder Encoder, currentKey []byte, b Buffer, datadir string) (
 	w := bufio.NewWriterSize(bufferFile, BufIOSize)
 	defer w.Flush() //nolint:errcheck
 
+	defer func() {
+		b.Reset() // run it after buf.flush and file.sync
+		var m runtime.MemStats
+		runtime.ReadMemStats(&m)
+		log.Info(
+			"Flushed buffer file",
+			"current key", makeCurrentKeyStr(currentKey),
+			"name", bufferFile.Name(),
+			"alloc", common.StorageSize(m.Alloc), "sys", common.StorageSize(m.Sys), "numGC", int(m.NumGC))
+	}()
+
 	encoder.Reset(w)
 	for _, entry := range b.GetEntries() {
 		err = writeToDisk(encoder, entry.key, entry.value)
@@ -47,14 +58,6 @@ func FlushToDisk(encoder Encoder, currentKey []byte, b Buffer, datadir string) (
 			return nil, fmt.Errorf("error writing entries to disk: %v", err)
 		}
 	}
-	var m runtime.MemStats
-	runtime.ReadMemStats(&m)
-	log.Info(
-		"Flushed buffer file",
-		"current key", makeCurrentKeyStr(currentKey),
-		"name", bufferFile.Name(),
-		"alloc", common.StorageSize(m.Alloc), "sys", common.StorageSize(m.Sys), "numGC", int(m.NumGC))
-	b.Reset()
 
 	return &fileDataProvider{bufferFile, nil}, nil
 }
diff --git a/common/pool/buffer.go b/common/pool/buffer.go
deleted file mode 100644
index 6c5082322..000000000
--- a/common/pool/buffer.go
+++ /dev/null
@@ -1,24 +0,0 @@
-package pool
-
-import "github.com/valyala/bytebufferpool"
-
-type ByteBuffer struct {
-	*bytebufferpool.ByteBuffer
-}
-
-func (b ByteBuffer) Get(pos int) byte {
-	return b.B[pos]
-}
-
-func (b ByteBuffer) SetBitPos(pos uint64) {
-	b.B[pos/8] |= 0x80 >> (pos % 8)
-}
-
-func (b ByteBuffer) SetBit8Pos(pos uint64) {
-	b.B[pos/8] |= 0xFF >> (pos % 8)
-	b.B[pos/8+1] |= ^(0xFF >> (pos % 8))
-}
-
-func (b ByteBuffer) CodeSegment(pos uint64) bool {
-	return b.B[pos/8]&(0x80>>(pos%8)) == 0
-}
diff --git a/common/pool/global_pool.go b/common/pool/global_pool.go
deleted file mode 100644
index a493bc6c2..000000000
--- a/common/pool/global_pool.go
+++ /dev/null
@@ -1,88 +0,0 @@
-package pool
-
-var (
-	chunkSizeClasses = []uint{
-		8,
-		64,
-		75,
-		128,
-		192,
-		1 << 8,
-		1 << 9,
-		1 << 10,
-		1 << 11,
-		1 << 12,
-		1 << 13,
-		1 << 14,
-		1 << 15,
-		1 << 16,
-		1 << 17,
-		1 << 18,
-		1 << 19,
-		1 << 20,
-	}
-	chunkPools []*pool
-)
-
-func init() {
-	// init chunkPools
-	for _, chunkSize := range chunkSizeClasses {
-		chunkPools = append(chunkPools, newPool(chunkSize))
-	}
-
-	// preallocate some buffers
-	const preAlloc = 32
-	for _, n := range chunkSizeClasses {
-
-		for i := 0; i < preAlloc; i++ {
-			PutBuffer(GetBuffer(n))
-		}
-	}
-}
-
-func GetBuffer(size uint) *ByteBuffer {
-	var i int
-	for i = 0; i < len(chunkSizeClasses)-1; i++ {
-		if size <= chunkSizeClasses[i] {
-			break
-		}
-	}
-
-	pp := chunkPools[i].Get()
-
-	if capB := cap(pp.B); uint(capB) < size {
-		if capB == 0 {
-			_ = pp.WriteByte(0)
-		}
-		if capB != 0 {
-			pp.B = pp.B[:capB]
-			_, _ = pp.Write(make([]byte, size-uint(capB)))
-		}
-	}
-
-	pp.B = pp.B[:size]
-
-	return pp
-}
-
-func GetBufferZeroed(size uint) *ByteBuffer {
-	pp := GetBuffer(size)
-	for i := range pp.B {
-		pp.B[i] = 0
-	}
-	return pp
-}
-
-func PutBuffer(p *ByteBuffer) {
-	if p == nil || cap(p.B) == 0 {
-		return
-	}
-
-	for i, n := range chunkSizeClasses {
-		if uint(cap(p.B)) <= n {
-			p.B = p.B[:0]
-			chunkPools[i].pool.Put(p)
-			break
-		}
-	}
-}
diff --git a/common/pool/pool.go b/common/pool/pool.go
deleted file mode 100644
index d5873d803..000000000
--- a/common/pool/pool.go
+++ /dev/null
@@ -1,63 +0,0 @@
-package pool
-
-import (
-	"sync"
-	"sync/atomic"
-
-	"github.com/valyala/bytebufferpool"
-)
-
-// pool represents byte buffer pool.
-//
-// Distinct pools may be used for distinct types of byte buffers.
-// Properly determined byte buffer types with their own pools may help reducing
-// memory waste.
-type pool struct {
-	defaultSize uint64
-	maxSize     uint64
-
-	pool sync.Pool
-}
-
-func newPool(defaultSize uint) *pool {
-	return &pool{
-		defaultSize: uint64(defaultSize),
-		maxSize:     uint64(defaultSize),
-		pool: sync.Pool{
-			New: getFn(defaultSize),
-		},
-	}
-}
-
-func getFn(defaultSize uint) func() interface{} {
-	return func() interface{} {
-		return &ByteBuffer{
-			&bytebufferpool.ByteBuffer{
-				B: make([]byte, 0, defaultSize),
-			},
-		}
-	}
-}
-
-// Get returns new byte buffer with zero length.
-//
-// The byte buffer may be returned to the pool via Put after the use
-// in order to minimize GC overhead.
-func (p *pool) Get() *ByteBuffer {
-	return p.pool.Get().(*ByteBuffer)
-}
-
-// Put releases byte buffer obtained via Get to the pool.
-//
-// The buffer mustn't be accessed after returning to the pool.
-func (p *pool) Put(b *ByteBuffer) {
-	if b == nil || cap(b.B) == 0 {
-		return
-	}
-
-	maxSize := int(atomic.LoadUint64(&p.maxSize))
-	if maxSize == 0 || cap(b.B) <= maxSize {
-		b.B = b.B[:0]
-		p.pool.Put(b)
-	}
-}
diff --git a/common/pool/pool_stack.go b/common/pool/pool_stack.go
deleted file mode 100644
index 459a25137..000000000
--- a/common/pool/pool_stack.go
+++ /dev/null
@@ -1,38 +0,0 @@
-package pool
-
-import (
-	"sync"
-
-	"github.com/ledgerwatch/turbo-geth/core/vm/stack"
-)
-
-var StackPool = NewStack()
-
-type Stack struct {
-	*sync.Pool
-}
-
-const maxCap = 1024 * 2
-
-func NewStack() *Stack {
-	return &Stack{
-		&sync.Pool{
-			New: func() interface{} {
-				return stack.New(maxCap)
-			},
-		},
-	}
-}
-
-func (p *Stack) Get() *stack.Stack {
-	return p.Pool.Get().(*stack.Stack)
-}
-
-func (p *Stack) Put(s *stack.Stack) {
-	if s == nil || s.Cap() == 0 || s.Cap() > maxCap {
-		return
-	}
-
-	s.Reset()
-	p.Pool.Put(s)
-}
diff --git a/core/state/database.go b/core/state/database.go
index 1d6741892..799ec8c40 100644
--- a/core/state/database.go
+++ b/core/state/database.go
@@ -249,7 +249,6 @@ func NewTrieDbState(root common.Hash, db ethdb.Database, blockNr uint64) *TrieDb
 	tp.SetBlockNumber(blockNr)
 
 	t.AddObserver(tp)
-	t.AddObserver(NewIntermediateHashes(tds.db, tds.db))
 
 	return tds
 }
@@ -291,7 +290,6 @@ func (tds *TrieDbState) Copy() *TrieDbState {
 	}
 
 	cpy.t.AddObserver(tp)
-	cpy.t.AddObserver(NewIntermediateHashes(cpy.db, cpy.db))
 
 	return &cpy
 }
diff --git a/core/state/intermediate_hashes.go b/core/state/intermediate_hashes.go
deleted file mode 100644
index a6b55c7ae..000000000
--- a/core/state/intermediate_hashes.go
+++ /dev/null
@@ -1,76 +0,0 @@
-package state
-
-import (
-	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/common/dbutils"
-	"github.com/ledgerwatch/turbo-geth/common/pool"
-	"github.com/ledgerwatch/turbo-geth/ethdb"
-	"github.com/ledgerwatch/turbo-geth/log"
-	"github.com/ledgerwatch/turbo-geth/metrics"
-	"github.com/ledgerwatch/turbo-geth/trie"
-)
-
-var (
-	InsertCounter = metrics.NewRegisteredCounter("db/ih/insert", nil)
-	DeleteCounter = metrics.NewRegisteredCounter("db/ih/delete", nil)
-)
-
-const keyBufferSize = 64
-
-type IntermediateHashes struct {
-	trie.NoopObserver // make sure that we don't need to subscribe to unnecessary methods
-	putter            ethdb.Putter
-	deleter           ethdb.Deleter
-}
-
-func NewIntermediateHashes(putter ethdb.Putter, deleter ethdb.Deleter) *IntermediateHashes {
-	return &IntermediateHashes{putter: putter, deleter: deleter}
-}
-
-func (ih *IntermediateHashes) WillUnloadBranchNode(prefixAsNibbles []byte, nodeHash common.Hash, incarnation uint64) {
-	// only put to bucket prefixes with even number of nibbles
-	if len(prefixAsNibbles) == 0 || len(prefixAsNibbles)%2 == 1 {
-		return
-	}
-
-	InsertCounter.Inc(1)
-
-	buf := pool.GetBuffer(keyBufferSize)
-	defer pool.PutBuffer(buf)
-	trie.CompressNibbles(prefixAsNibbles, &buf.B)
-
-	var key []byte
-	if len(buf.B) >= common.HashLength {
-		key = dbutils.GenerateCompositeStoragePrefix(buf.B[:common.HashLength], incarnation, buf.B[common.HashLength:])
-	} else {
-		key = common.CopyBytes(buf.B)
-	}
-
-	if err := ih.putter.Put(dbutils.IntermediateTrieHashBucket, key, common.CopyBytes(nodeHash[:])); err != nil {
-		log.Warn("could not put intermediate trie hash", "err", err)
-	}
-}
-
-func (ih *IntermediateHashes) BranchNodeLoaded(prefixAsNibbles []byte, incarnation uint64) {
-	// only put to bucket prefixes with even number of nibbles
-	if len(prefixAsNibbles) == 0 || len(prefixAsNibbles)%2 == 1 {
-		return
-	}
-	DeleteCounter.Inc(1)
-
-	buf := pool.GetBuffer(keyBufferSize)
-	defer pool.PutBuffer(buf)
-	trie.CompressNibbles(prefixAsNibbles, &buf.B)
-
-	var key []byte
-	if len(buf.B) >= common.HashLength {
-		key = dbutils.GenerateCompositeStoragePrefix(buf.B[:common.HashLength], incarnation, buf.B[common.HashLength:])
-	} else {
-		key = common.CopyBytes(buf.B)
-	}
-
-	if err := ih.deleter.Delete(dbutils.IntermediateTrieHashBucket, key); err != nil {
-		log.Warn("could not delete intermediate trie hash", "err", err)
-	}
-
-}
diff --git a/core/types/accounts/account.go b/core/types/accounts/account.go
index 0097ef838..884857e03 100644
--- a/core/types/accounts/account.go
+++ b/core/types/accounts/account.go
@@ -4,11 +4,10 @@ import (
 	"fmt"
 	"io"
 	"math/bits"
+	"sync"
 
 	"github.com/holiman/uint256"
-
 	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/common/pool"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 )
@@ -172,12 +171,27 @@ func decodeLengthForHashing(buffer []byte, pos int) (length int, structure bool,
 	}
 }
 
+var rlpEncodingBufPool = sync.Pool{
+	New: func() interface{} {
+		buf := make([]byte, 0, 128)
+		return &buf
+	},
+}
+
 func (a *Account) EncodeRLP(w io.Writer) error {
-	len := a.EncodingLengthForHashing()
-	buffer := pool.GetBuffer(len)
-	a.EncodeForHashing(buffer.Bytes())
-	_, err := w.Write(buffer.Bytes())
-	pool.PutBuffer(buffer)
+	var buf []byte
+	l := a.EncodingLengthForHashing()
+	if l > 128 {
+		buf = make([]byte, l)
+	} else {
+		bp := rlpEncodingBufPool.Get().(*[]byte)
+		defer rlpEncodingBufPool.Put(bp)
+		buf = *bp
+		buf = buf[:l]
+	}
+
+	a.EncodeForHashing(buf)
+	_, err := w.Write(buf)
 	return err
 }
 
diff --git a/core/types/accounts/account_benchmark_test.go b/core/types/accounts/account_benchmark_test.go
index e1736905f..0db85538f 100644
--- a/core/types/accounts/account_benchmark_test.go
+++ b/core/types/accounts/account_benchmark_test.go
@@ -8,7 +8,6 @@ import (
 	"github.com/holiman/uint256"
 
 	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/common/pool"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 )
 
@@ -160,15 +159,10 @@ func BenchmarkEncodingAccountForStorage(b *testing.B) {
 	for _, test := range accountCases {
 		test := test
 
+		buf := make([]byte, test.acc.EncodingLengthForStorage())
 		b.Run(fmt.Sprint(test.name), func(b *testing.B) {
 			for i := 0; i < b.N; i++ {
-				b.StopTimer()
-				encodedLen := test.acc.EncodingLengthForStorage()
-				b.StartTimer()
-
-				encodedAccount := pool.GetBuffer(encodedLen)
-				test.acc.EncodeForStorage(encodedAccount.B)
-				pool.PutBuffer(encodedAccount)
+				test.acc.EncodeForStorage(buf)
 			}
 		})
 	}
@@ -219,15 +213,10 @@ func BenchmarkEncodingAccountForHashing(b *testing.B) {
 	b.ResetTimer()
 	for _, test := range accountCases {
 		test := test
+		buf := make([]byte, test.acc.EncodingLengthForStorage())
 		b.Run(fmt.Sprint(test.name), func(b *testing.B) {
 			for i := 0; i < b.N; i++ {
-				b.StopTimer()
-				encodedLen := test.acc.EncodingLengthForHashing()
-				b.StartTimer()
-
-				encodedAccount := pool.GetBuffer(encodedLen)
-				test.acc.EncodeForHashing(encodedAccount.B)
-				pool.PutBuffer(encodedAccount)
+				test.acc.EncodeForHashing(buf)
 			}
 		})
 	}
@@ -279,27 +268,25 @@ func BenchmarkDecodingAccount(b *testing.B) {
 	b.ResetTimer()
 	for _, test := range accountCases {
 		test := test
+		encodedAccount := make([]byte, test.acc.EncodingLengthForStorage())
 		b.Run(fmt.Sprint(test.name), func(b *testing.B) {
 			for i := 0; i < b.N; i++ {
 				b.StopTimer()
 				test.acc.Nonce = uint64(i)
 				test.acc.Balance.SetUint64(uint64(i))
 
-				encodedAccount := pool.GetBuffer(test.acc.EncodingLengthForStorage())
-				test.acc.EncodeForStorage(encodedAccount.B)
+				test.acc.EncodeForStorage(encodedAccount)
 
 				b.StartTimer()
 
 				var decodedAccount Account
-				if err := decodedAccount.DecodeForStorage(encodedAccount.B); err != nil {
+				if err := decodedAccount.DecodeForStorage(encodedAccount); err != nil {
 					b.Fatal("cant decode the account", err, encodedAccount)
 				}
 
 				b.StopTimer()
 				decodedAccounts = append(decodedAccounts, decodedAccount)
 				b.StartTimer()
-
-				pool.PutBuffer(encodedAccount)
 			}
 		})
 	}
diff --git a/core/types/accounts/account_test.go b/core/types/accounts/account_test.go
index fbef438ab..75bf6a7e1 100644
--- a/core/types/accounts/account_test.go
+++ b/core/types/accounts/account_test.go
@@ -6,7 +6,6 @@ import (
 	"github.com/holiman/uint256"
 
 	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/common/pool"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 )
 
@@ -20,17 +19,15 @@ func TestEmptyAccount(t *testing.T) {
 		Incarnation: 5,
 	}
 
-	encodedAccount := pool.GetBuffer(a.EncodingLengthForStorage())
-	a.EncodeForStorage(encodedAccount.B)
+	encodedAccount := make([]byte, a.EncodingLengthForStorage())
+	a.EncodeForStorage(encodedAccount)
 
 	var decodedAccount Account
-	if err := decodedAccount.DecodeForStorage(encodedAccount.B); err != nil {
+	if err := decodedAccount.DecodeForStorage(encodedAccount); err != nil {
 		t.Fatal("cant decode the account", err, encodedAccount)
 	}
 
 	isAccountsEqual(t, a, decodedAccount)
-
-	pool.PutBuffer(encodedAccount)
 }
 
 func TestEmptyAccount2(t *testing.T) {
@@ -50,11 +47,11 @@ func TestEmptyAccount2(t *testing.T) {
 func TestEmptyAccount_BufferStrangeBehaviour(t *testing.T) {
 	a := Account{}
 
-	encodedAccount := pool.GetBuffer(a.EncodingLengthForStorage())
-	a.EncodeForStorage(encodedAccount.B)
+	encodedAccount := make([]byte, a.EncodingLengthForStorage())
+	a.EncodeForStorage(encodedAccount)
 
 	var decodedAccount Account
-	if err := decodedAccount.DecodeForStorage(encodedAccount.Bytes()); err != nil {
+	if err := decodedAccount.DecodeForStorage(encodedAccount); err != nil {
 		t.Fatal("cant decode the account", err, encodedAccount)
 	}
 }
diff --git a/core/vm/analysis.go b/core/vm/analysis.go
index 1779b7964..bf72faf13 100644
--- a/core/vm/analysis.go
+++ b/core/vm/analysis.go
@@ -17,40 +17,99 @@
 package vm
 
 import (
+	"sync"
+
 	"github.com/hashicorp/golang-lru"
 	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/common/pool"
+	"github.com/valyala/bytebufferpool"
 )
 
 type Cache interface {
 	Len() int
-	Set(hash common.Hash, v *pool.ByteBuffer)
-	Get(hash common.Hash) (*pool.ByteBuffer, bool)
-	Clear(codeHash common.Hash, local *pool.ByteBuffer)
+	Set(hash common.Hash, v *ByteBuffer)
+	Get(hash common.Hash) (*ByteBuffer, bool)
+	Clear(codeHash common.Hash, local *ByteBuffer)
 }
 
 type DestsCache struct {
 	*lru.Cache
 }
 
+type ByteBuffer struct {
+	*bytebufferpool.ByteBuffer
+}
+
+func (b ByteBuffer) Get(pos int) byte {
+	return b.B[pos]
+}
+
+func (b ByteBuffer) SetBitPos(pos uint64) {
+	b.B[pos/8] |= 0x80 >> (pos % 8)
+}
+
+func (b ByteBuffer) SetBit8Pos(pos uint64) {
+	b.B[pos/8] |= 0xFF >> (pos % 8)
+	b.B[pos/8+1] |= ^(0xFF >> (pos % 8))
+}
+
+func (b ByteBuffer) CodeSegment(pos uint64) bool {
+	return b.B[pos/8]&(0x80>>(pos%8)) == 0
+}
+
+type buffPoolT struct {
+	p        sync.Pool
+	capacity int // drop all buffers more than this threshold to keep constant mem usage by pool
+}
+
+func (p *buffPoolT) Put(b *ByteBuffer) {
+	if b == nil {
+		return
+	}
+	if b.Len() > p.capacity {
+		return
+	}
+}
+
+func (p *buffPoolT) Get(size uint) *ByteBuffer {
+	pp := p.p.Get().(*ByteBuffer)
+	if uint(cap(pp.B)) < size {
+		pp.B = append(pp.B[:cap(pp.B)], make([]byte, size-uint(cap(pp.B)))...)
+	}
+	pp.B = pp.B[:size]
+
+	for i := range pp.B {
+		pp.B[i] = 0
+	}
+	return pp
+}
+
+var buffPool = buffPoolT{
+	capacity: 2048,
+	p: sync.Pool{
+		New: func() interface{} {
+			return &ByteBuffer{ByteBuffer: &bytebufferpool.ByteBuffer{B: make([]byte, 0, 2048)}}
+		},
+	},
+}
+
 func NewDestsCache(maxSize int) *DestsCache {
 	c, _ := lru.New(maxSize)
 	return &DestsCache{c}
 }
 
-func (d *DestsCache) Set(hash common.Hash, v *pool.ByteBuffer) {
+func (d *DestsCache) Set(hash common.Hash, v *ByteBuffer) {
 	d.Add(hash, v)
 }
 
-func (d DestsCache) Get(hash common.Hash) (*pool.ByteBuffer, bool) {
+func (d DestsCache) Get(hash common.Hash) (*ByteBuffer, bool) {
 	v, ok := d.Cache.Get(hash)
 	if !ok {
 		return nil, false
 	}
-	return v.(*pool.ByteBuffer), ok
+	return v.(*ByteBuffer), ok
 }
 
-func (d *DestsCache) Clear(codeHash common.Hash, local *pool.ByteBuffer) {
+func (d *DestsCache) Clear(codeHash common.Hash, local *ByteBuffer) {
 	if codeHash == (common.Hash{}) {
 		return
 	}
@@ -59,7 +118,7 @@ func (d *DestsCache) Clear(codeHash common.Hash, local *pool.ByteBuffer) {
 		return
 	}
 	// analysis is a local one
-	pool.PutBuffer(local)
+	buffPool.Put(local)
 }
 
 func (d *DestsCache) Len() int {
@@ -67,11 +126,11 @@ func (d *DestsCache) Len() int {
 }
 
 // codeBitmap collects data locations in code.
-func codeBitmap(code []byte) *pool.ByteBuffer {
+func codeBitmap(code []byte) *ByteBuffer {
 	// The bitmap is 4 bytes longer than necessary, in case the code
 	// ends with a PUSH32, the algorithm will push zeroes onto the
 	// bitvector outside the bounds of the actual code.
-	bits := pool.GetBufferZeroed(uint(len(code)/8 + 1 + 4))
+	bits := buffPool.Get(uint(len(code)/8 + 1 + 4))
 
 	for pc := uint64(0); pc < uint64(len(code)); {
 		op := OpCode(code[pc])
diff --git a/core/vm/analysis_test.go b/core/vm/analysis_test.go
index cc8f65139..d3fdb3991 100644
--- a/core/vm/analysis_test.go
+++ b/core/vm/analysis_test.go
@@ -24,7 +24,6 @@ import (
 	"github.com/holiman/uint256"
 
 	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/common/pool"
 	"github.com/ledgerwatch/turbo-geth/crypto"
 )
 
@@ -63,7 +62,8 @@ func TestJumpDestAnalysis(t *testing.T) {
 
 func BenchmarkJumpdestSet8(b *testing.B) {
 	const size = 1000
-	bits := pool.GetBuffer(size)
+	bits := buffPool.Get(size)
+	defer buffPool.Put(bits)
 	b.ResetTimer()
 	for n := 0; n < b.N; n++ {
 		for i := uint64(0); i < size*8-8; i++ {
@@ -76,7 +76,8 @@ func BenchmarkJumpdestSet8(b *testing.B) {
 
 func BenchmarkJumpdestSet(b *testing.B) {
 	const size = 1000
-	bits := pool.GetBuffer(size)
+	bits := buffPool.Get(size)
+	defer buffPool.Put(bits)
 	b.ResetTimer()
 	for n := 0; n < b.N; n++ {
 		for i := uint64(0); i < 8*size; i++ {
@@ -93,7 +94,7 @@ func BenchmarkJumpdestAnalysisEmpty_1200k(bench *testing.B) {
 	bench.ResetTimer()
 	for i := 0; i < bench.N; i++ {
 		b := codeBitmap(code)
-		pool.PutBuffer(b)
+		buffPool.Put(b)
 	}
 	bench.StopTimer()
 }
@@ -103,7 +104,7 @@ func BenchmarkJumpdestAnalysis_1200k(bench *testing.B) {
 	bench.ResetTimer()
 	for i := 0; i < bench.N; i++ {
 		b := codeBitmap(code)
-		pool.PutBuffer(b)
+		buffPool.Put(b)
 	}
 	bench.StopTimer()
 }
diff --git a/core/vm/contract.go b/core/vm/contract.go
index 24cb7561b..4a25401af 100644
--- a/core/vm/contract.go
+++ b/core/vm/contract.go
@@ -20,7 +20,6 @@ import (
 	"github.com/holiman/uint256"
 
 	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/common/pool"
 )
 
 // ContractRef is a reference to the contract's backing object
@@ -50,7 +49,7 @@ type Contract struct {
 	caller        ContractRef
 	self          ContractRef
 
-	analysis *pool.ByteBuffer // Locally cached result of JUMPDEST analysis
+	analysis *ByteBuffer // Locally cached result of JUMPDEST analysis
 	dests    Cache
 
 	Code     []byte
diff --git a/core/vm/interpreter.go b/core/vm/interpreter.go
index ac457fc4e..00c098245 100644
--- a/core/vm/interpreter.go
+++ b/core/vm/interpreter.go
@@ -18,11 +18,11 @@ package vm
 
 import (
 	"hash"
+	"sync"
 	"sync/atomic"
 
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/math"
-	"github.com/ledgerwatch/turbo-geth/common/pool"
 	"github.com/ledgerwatch/turbo-geth/core/vm/stack"
 	"github.com/ledgerwatch/turbo-geth/log"
 )
@@ -79,6 +79,37 @@ type keccakState interface {
 	Read([]byte) (int, error)
 }
 
+var stackPool = NewStack()
+
+type Stack struct {
+	*sync.Pool
+}
+
+const maxCap = 1024 * 2
+
+func NewStack() *Stack {
+	return &Stack{
+		&sync.Pool{
+			New: func() interface{} {
+				return stack.New(maxCap)
+			},
+		},
+	}
+}
+
+func (p *Stack) Get() *stack.Stack {
+	return p.Pool.Get().(*stack.Stack)
+}
+
+func (p *Stack) Put(s *stack.Stack) {
+	if s == nil || s.Cap() == 0 || s.Cap() > maxCap {
+		return
+	}
+
+	s.Reset()
+	p.Pool.Put(s)
+}
+
 // EVMInterpreter represents an EVM interpreter
 type EVMInterpreter struct {
 	evm *EVM
@@ -163,7 +194,7 @@ func (in *EVMInterpreter) Run(contract *Contract, input []byte, readOnly bool) (
 	var (
 		op          OpCode        // current opcode
 		mem         = NewMemory() // bound memory
-		locStack    = pool.StackPool.Get()
+		locStack    = stackPool.Get()
 		returns     = stack.NewReturnStack() // local returns stack
 		callContext = &callCtx{
 			memory:   mem,
@@ -182,7 +213,7 @@ func (in *EVMInterpreter) Run(contract *Contract, input []byte, readOnly bool) (
 		logged  bool   // deferred Tracer should ignore already logged steps
 		res     []byte // result of the opcode execution function
 	)
-	defer pool.StackPool.Put(locStack)
+	defer stackPool.Put(locStack)
 	contract.Input = input
 
 	if in.cfg.Debug {
diff --git a/trie/debug.go b/trie/debug.go
index 0d82683a0..2ececa194 100644
--- a/trie/debug.go
+++ b/trie/debug.go
@@ -24,7 +24,6 @@ import (
 	"io"
 
 	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/common/pool"
 )
 
 func (t *Trie) Print(w io.Writer) {
@@ -133,21 +132,19 @@ func (n codeNode) print(w io.Writer) {
 }
 
 func (an accountNode) fstring(ind string) string {
-	encodedAccount := pool.GetBuffer(an.EncodingLengthForHashing())
-	an.EncodeForHashing(encodedAccount.B)
-	defer pool.PutBuffer(encodedAccount)
+	encodedAccount := make([]byte, an.EncodingLengthForHashing())
+	an.EncodeForHashing(encodedAccount)
 	if an.storage == nil {
-		return fmt.Sprintf("%x", encodedAccount.String())
+		return fmt.Sprintf("%x", encodedAccount)
 	}
-	return fmt.Sprintf("%x %v", encodedAccount.String(), an.storage.fstring(ind+" "))
+	return fmt.Sprintf("%x %v", encodedAccount, an.storage.fstring(ind+" "))
 }
 
 func (an accountNode) print(w io.Writer) {
-	encodedAccount := pool.GetBuffer(an.EncodingLengthForHashing())
-	an.EncodeForHashing(encodedAccount.B)
-	defer pool.PutBuffer(encodedAccount)
+	encodedAccount := make([]byte, an.EncodingLengthForHashing())
+	an.EncodeForHashing(encodedAccount)
 
-	fmt.Fprintf(w, "v(%x)", encodedAccount.String())
+	fmt.Fprintf(w, "v(%x)", encodedAccount)
 }
 
 func printDiffSide(n node, w io.Writer, ind string, key string) {
diff --git a/trie/hasher.go b/trie/hasher.go
index 17ad37150..a45aef31b 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -24,7 +24,6 @@ import (
 	"golang.org/x/crypto/sha3"
 
 	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/common/pool"
 	"github.com/ledgerwatch/turbo-geth/rlp"
 	"github.com/ledgerwatch/turbo-geth/trie/rlphacks"
 )
@@ -273,13 +272,7 @@ func (h *hasher) hashChildren(original node, bufOffset int) ([]byte, error) {
 
 	case *accountNode:
 		// we don't do double RLP here, so `accountNodeToBuffer` is not applicable
-		encodedAccount := pool.GetBuffer(n.EncodingLengthForHashing())
-
-		n.EncodeForHashing(encodedAccount.B)
-		pos += copy(buffer[pos:], encodedAccount.Bytes())
-
-		pool.PutBuffer(encodedAccount)
-
+		n.EncodeForHashing(buffer[pos:])
 		return buffer[rlpPrefixLength:pos], nil
 
 	case hashNode:
@@ -307,12 +300,8 @@ func (h *hasher) valueNodeToBuffer(vn valueNode, buffer []byte, pos int) (int, e
 }
 
 func (h *hasher) accountNodeToBuffer(ac *accountNode, buffer []byte, pos int) (int, error) {
-	encodedAccount := pool.GetBuffer(ac.EncodingLengthForHashing())
-	defer pool.PutBuffer(encodedAccount)
-
-	ac.EncodeForHashing(encodedAccount.B)
-	acRlp := encodedAccount.Bytes()
-
+	acRlp := make([]byte, ac.EncodingLengthForHashing())
+	ac.EncodeForHashing(acRlp)
 	enc := rlphacks.RlpEncodedBytes(acRlp)
 	h.bw.Setup(buffer, pos)
 
diff --git a/trie/intermediate_hashes_test.go b/trie/intermediate_hashes_test.go
index 3258f6d0f..a89199230 100644
--- a/trie/intermediate_hashes_test.go
+++ b/trie/intermediate_hashes_test.go
@@ -6,7 +6,6 @@ import (
 	"testing"
 
 	"github.com/ledgerwatch/turbo-geth/common"
-	"github.com/ledgerwatch/turbo-geth/common/pool"
 	"github.com/stretchr/testify/assert"
 )
 
@@ -22,21 +21,17 @@ func TestCompressNibbles(t *testing.T) {
 		{in: "", expect: ""},
 	}
 
-	compressBuf := pool.GetBuffer(64)
-	defer pool.PutBuffer(compressBuf)
-	decompressBuf := pool.GetBuffer(64)
-	defer pool.PutBuffer(decompressBuf)
+	compressed := make([]byte, 64)
+	decompressed := make([]byte, 64)
 	for _, tc := range cases {
-		compressBuf.Reset()
-		decompressBuf.Reset()
+		compressed = compressed[:0]
+		decompressed = decompressed[:0]
 
 		in := common.Hex2Bytes(tc.in)
-		CompressNibbles(in, &compressBuf.B)
-		compressed := compressBuf.Bytes()
+		CompressNibbles(in, &compressed)
 		msg := "On: " + tc.in + " Len: " + strconv.Itoa(len(compressed))
 		assert.Equal(t, tc.expect, fmt.Sprintf("%x", compressed), msg)
-		DecompressNibbles(compressed, &decompressBuf.B)
-		decompressed := decompressBuf.Bytes()
+		DecompressNibbles(compressed, &decompressed)
 		assert.Equal(t, tc.in, fmt.Sprintf("%x", decompressed), msg)
 	}
 }
