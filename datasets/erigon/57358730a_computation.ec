commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
commit 57358730a44e1c6256c0ccb1b676a8a5d370dd38
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Mon Jun 15 19:30:54 2020 +0700

    Minor lmdb related improvements (#667)
    
    * don't call initCursor on happy path
    
    * don't call initCursor on happy path
    
    * don't run stale reads goroutine for inMem mode
    
    * don't call initCursor on happy path
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * commit kv benchmark
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * remove buffers from cursor object - they are useful only in Badger implementation
    
    * cancel server before return pipe to pool
    
    * try  to fix test
    
    * set field db in managed tx

diff --git a/.golangci/step4.yml b/.golangci/step4.yml
index f926a891f..223c89930 100644
--- a/.golangci/step4.yml
+++ b/.golangci/step4.yml
@@ -10,6 +10,7 @@ linters:
     - typecheck
     - unused
     - misspell
+    - maligned
 
 issues:
   exclude-rules:
diff --git a/Makefile b/Makefile
index e97f6fd49..0cfe63c80 100644
--- a/Makefile
+++ b/Makefile
@@ -91,7 +91,7 @@ ios:
 	@echo "Import \"$(GOBIN)/Geth.framework\" to use the library."
 
 test: semantics/z3/build/libz3.a all
-	TEST_DB=bolt $(GORUN) build/ci.go test
+	TEST_DB=lmdb $(GORUN) build/ci.go test
 
 test-lmdb: semantics/z3/build/libz3.a all
 	TEST_DB=lmdb $(GORUN) build/ci.go test
diff --git a/ethdb/abstractbench/abstract_bench_test.go b/ethdb/abstractbench/abstract_bench_test.go
index a5a8e7b8f..f83f3d806 100644
--- a/ethdb/abstractbench/abstract_bench_test.go
+++ b/ethdb/abstractbench/abstract_bench_test.go
@@ -3,23 +3,26 @@ package abstractbench
 import (
 	"context"
 	"encoding/binary"
+	"math/rand"
 	"os"
 	"sort"
 	"testing"
+	"time"
 
-	"github.com/dgraph-io/badger/v2"
 	"github.com/ledgerwatch/bolt"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
 )
 
 var boltOriginDb *bolt.DB
-var badgerOriginDb *badger.DB
-var boltDb ethdb.KV
-var badgerDb ethdb.KV
-var lmdbKV ethdb.KV
 
-var keysAmount = 1_000_000
+//var badgerOriginDb *badger.DB
+var boltKV *ethdb.BoltKV
+
+//var badgerDb ethdb.KV
+var lmdbKV *ethdb.LmdbKV
+
+var keysAmount = 100_000
 
 func setupDatabases() func() {
 	//vsize, ctx := 10, context.Background()
@@ -31,11 +34,15 @@ func setupDatabases() func() {
 		os.RemoveAll("test4")
 		os.RemoveAll("test5")
 	}
-	boltDb = ethdb.NewBolt().Path("test").MustOpen()
+	//boltKV = ethdb.NewBolt().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me2/geth/chaindata").ReadOnly().MustOpen().(*ethdb.BoltKV)
+	boltKV = ethdb.NewBolt().Path("test1").MustOpen().(*ethdb.BoltKV)
 	//badgerDb = ethdb.NewBadger().Path("test2").MustOpen()
-	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen()
+	//lmdbKV = ethdb.NewLMDB().Path("/Users/alex.sharov/Library/Ethereum/geth-remove-me4/geth/chaindata_lmdb").ReadOnly().MustOpen().(*ethdb.LmdbKV)
+	lmdbKV = ethdb.NewLMDB().Path("test4").MustOpen().(*ethdb.LmdbKV)
 	var errOpen error
-	boltOriginDb, errOpen = bolt.Open("test3", 0600, &bolt.Options{KeysPrefixCompressionDisable: true})
+	o := bolt.DefaultOptions
+	o.KeysPrefixCompressionDisable = true
+	boltOriginDb, errOpen = bolt.Open("test3", 0600, o)
 	if errOpen != nil {
 		panic(errOpen)
 	}
@@ -45,10 +52,17 @@ func setupDatabases() func() {
 	//	panic(errOpen)
 	//}
 
-	_ = boltOriginDb.Update(func(tx *bolt.Tx) error {
-		_, _ = tx.CreateBucketIfNotExists(dbutils.CurrentStateBucket, false)
+	if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
+		for _, name := range dbutils.Buckets {
+			_, createErr := tx.CreateBucketIfNotExists(name, false)
+			if createErr != nil {
+				return createErr
+			}
+		}
 		return nil
-	})
+	}); err != nil {
+		panic(err)
+	}
 
 	//if err := boltOriginDb.Update(func(tx *bolt.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("origin bolt filled:", time.Since(t)) }(time.Now())
@@ -66,7 +80,7 @@ func setupDatabases() func() {
 	//	panic(err)
 	//}
 	//
-	//if err := boltDb.Update(ctx, func(tx ethdb.Tx) error {
+	//if err := boltKV.Update(ctx, func(tx ethdb.Tx) error {
 	//	defer func(t time.Time) { fmt.Println("abstract bolt filled:", time.Since(t)) }(time.Now())
 	//
 	//	for i := 0; i < keysAmount; i++ {
@@ -141,52 +155,89 @@ func setupDatabases() func() {
 func BenchmarkGet(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	k := make([]byte, 8)
-	binary.BigEndian.PutUint64(k, uint64(keysAmount-1))
+	//b.Run("badger", func(b *testing.B) {
+	//	db := ethdb.NewObjectDatabase(badgerDb)
+	//	for i := 0; i < b.N; i++ {
+	//		_, _ = db.Get(dbutils.CurrentStateBucket, k)
+	//	}
+	//})
+	ctx := context.Background()
 
-	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
-		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
-		}
-	})
-	b.Run("badger", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(badgerDb)
+	rand.Seed(time.Now().Unix())
+	b.Run("lmdb1", func(b *testing.B) {
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := lmdbKV.Get(ctx, dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
-	b.Run("lmdb", func(b *testing.B) {
+
+	b.Run("lmdb2", func(b *testing.B) {
 		db := ethdb.NewObjectDatabase(lmdbKV)
+		k := make([]byte, 9)
+		k[8] = dbutils.HeaderHashSuffix[0]
+		//k1 := make([]byte, 8+32)
+		j := rand.Uint64() % 1
+		binary.BigEndian.PutUint64(k, j)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
-			for j := 0; j < 10; j++ {
-				_, _ = db.Get(dbutils.CurrentStateBucket, k)
-			}
+			canonicalHash, _ := db.Get(dbutils.HeaderPrefix, k)
+			_ = canonicalHash
+			//copy(k1[8:], canonicalHash)
+			//binary.BigEndian.PutUint64(k1, uint64(j))
+			//v1, _ := lmdbKV.Get1(ctx, dbutils.HeaderPrefix, k1)
+			//v2, _ := lmdbKV.Get1(ctx, dbutils.BlockBodyPrefix, k1)
+			//_, _, _ = len(canonicalHash), len(v1), len(v2)
 		}
 	})
+
+	//b.Run("bolt", func(b *testing.B) {
+	//	k := make([]byte, 9)
+	//	k[8] = dbutils.HeaderHashSuffix[0]
+	//	//k1 := make([]byte, 8+32)
+	//	j := rand.Uint64() % 1
+	//	binary.BigEndian.PutUint64(k, j)
+	//	b.ResetTimer()
+	//	for i := 0; i < b.N; i++ {
+	//		canonicalHash, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k)
+	//		_ = canonicalHash
+	//		//binary.BigEndian.PutUint64(k1, uint64(j))
+	//		//copy(k1[8:], canonicalHash)
+	//		//v1, _ := boltKV.Get(ctx, dbutils.HeaderPrefix, k1)
+	//		//v2, _ := boltKV.Get(ctx, dbutils.BlockBodyPrefix, k1)
+	//		//_, _, _ = len(canonicalHash), len(v1), len(v2)
+	//	}
+	//})
 }
 
 func BenchmarkPut(b *testing.B) {
 	clean := setupDatabases()
 	defer clean()
-	tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
-	for i := 0; i < keysAmount; i++ {
-		k := make([]byte, 8)
-		binary.BigEndian.PutUint64(k, uint64(i))
-		v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
-		tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
-	}
-	sort.Sort(tuples)
 
 	b.Run("bolt", func(b *testing.B) {
-		db := ethdb.NewWrapperBoltDatabase(boltOriginDb).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		db := ethdb.NewWrapperBoltDatabase(boltOriginDb)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 	//b.Run("badger", func(b *testing.B) {
@@ -196,10 +247,20 @@ func BenchmarkPut(b *testing.B) {
 	//	}
 	//})
 	b.Run("lmdb", func(b *testing.B) {
-		db := ethdb.NewObjectDatabase(lmdbKV).NewBatch()
+		tuples := make(ethdb.MultiPutTuples, 0, keysAmount*3)
+		for i := 0; i < keysAmount; i++ {
+			k := make([]byte, 8)
+			j := rand.Uint64() % 100_000_000
+			binary.BigEndian.PutUint64(k, j)
+			v := []byte{1, 2, 3, 4, 5, 6, 7, 8}
+			tuples = append(tuples, dbutils.CurrentStateBucket, k, v)
+		}
+		sort.Sort(tuples)
+		var kv ethdb.KV = lmdbKV
+		db := ethdb.NewObjectDatabase(kv)
+		b.ResetTimer()
 		for i := 0; i < b.N; i++ {
 			_, _ = db.MultiPut(tuples...)
-			_, _ = db.Commit()
 		}
 	})
 }
@@ -213,7 +274,7 @@ func BenchmarkCursor(b *testing.B) {
 	b.ResetTimer()
 	b.Run("abstract bolt", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
@@ -230,7 +291,7 @@ func BenchmarkCursor(b *testing.B) {
 	})
 	b.Run("abstract lmdb", func(b *testing.B) {
 		for i := 0; i < b.N; i++ {
-			if err := boltDb.View(ctx, func(tx ethdb.Tx) error {
+			if err := boltKV.View(ctx, func(tx ethdb.Tx) error {
 				c := tx.Bucket(dbutils.CurrentStateBucket).Cursor()
 				for k, v, err := c.First(); k != nil; k, v, err = c.Next() {
 					if err != nil {
diff --git a/ethdb/kv_abstract.go b/ethdb/kv_abstract.go
index 32d71b779..a2c7c7bc9 100644
--- a/ethdb/kv_abstract.go
+++ b/ethdb/kv_abstract.go
@@ -16,9 +16,6 @@ type KV interface {
 
 type NativeGet interface {
 	Get(ctx context.Context, bucket, key []byte) ([]byte, error)
-}
-
-type NativeHas interface {
 	Has(ctx context.Context, bucket, key []byte) (bool, error)
 }
 
diff --git a/ethdb/kv_bolt.go b/ethdb/kv_bolt.go
index d16ded9d4..ace9f49d7 100644
--- a/ethdb/kv_bolt.go
+++ b/ethdb/kv_bolt.go
@@ -235,9 +235,7 @@ func (db *BoltKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 	return res, nil
 }
 
-func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	var err error
-	var val []byte
+func (db *BoltKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.bolt.View(func(tx *bolt.Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 2e1dec789..34e38411d 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -57,7 +57,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(32 << 20) // 32MB
+		err = env.SetMapSize(64 << 20) // 64MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
@@ -87,7 +87,15 @@ func (opts lmdbOpts) Open() (KV, error) {
 		return nil, err
 	}
 
-	buckets := make([]lmdb.DBI, len(dbutils.Buckets))
+	db := &LmdbKV{
+		opts:            opts,
+		env:             env,
+		log:             logger,
+		lmdbTxPool:      lmdbpool.NewTxnPool(env),
+		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	}
+
+	db.buckets = make([]lmdb.DBI, len(dbutils.Buckets))
 	if opts.readOnly {
 		if err := env.View(func(tx *lmdb.Txn) error {
 			for _, name := range dbutils.Buckets {
@@ -95,7 +103,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -108,7 +116,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 				if createErr != nil {
 					return createErr
 				}
-				buckets[dbutils.BucketsIndex[string(name)]] = dbi
+				db.buckets[dbutils.BucketsIndex[string(name)]] = dbi
 			}
 			return nil
 		}); err != nil {
@@ -116,23 +124,16 @@ func (opts lmdbOpts) Open() (KV, error) {
 		}
 	}
 
-	db := &LmdbKV{
-		opts:            opts,
-		env:             env,
-		log:             logger,
-		buckets:         buckets,
-		lmdbTxPool:      lmdbpool.NewTxnPool(env),
-		lmdbCursorPools: make([]sync.Pool, len(dbutils.Buckets)),
+	if !opts.inMem {
+		ctx, ctxCancel := context.WithCancel(context.Background())
+		db.stopStaleReadsCheck = ctxCancel
+		go func() {
+			ticker := time.NewTicker(time.Minute)
+			defer ticker.Stop()
+			db.staleReadsCheckLoop(ctx, ticker)
+		}()
 	}
 
-	ctx, ctxCancel := context.WithCancel(context.Background())
-	db.stopStaleReadsCheck = ctxCancel
-	go func() {
-		ticker := time.NewTicker(time.Minute)
-		defer ticker.Stop()
-		db.staleReadsCheckLoop(ctx, ticker)
-	}()
-
 	return db, nil
 }
 
@@ -212,19 +213,15 @@ func (db *LmdbKV) BucketsStat(_ context.Context) (map[string]common.StorageBucke
 }
 
 func (db *LmdbKV) dbi(bucket []byte) lmdb.DBI {
-	id, ok := dbutils.BucketsIndex[string(bucket)]
-	if !ok {
-		panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
+	if id, ok := dbutils.BucketsIndex[string(bucket)]; ok {
+		return db.buckets[id]
 	}
-	return db.buckets[id]
+	panic(fmt.Errorf("unknown bucket: %s. add it to dbutils.Buckets", string(bucket)))
 }
 
-func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
-	dbi := db.dbi(bucket)
-	var err error
-	var val []byte
+func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) (val []byte, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -243,13 +240,9 @@ func (db *LmdbKV) Get(ctx context.Context, bucket, key []byte) ([]byte, error) {
 	return val, nil
 }
 
-func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (bool, error) {
-	dbi := db.dbi(bucket)
-
-	var err error
-	var has bool
+func (db *LmdbKV) Has(ctx context.Context, bucket, key []byte) (has bool, err error) {
 	err = db.View(ctx, func(tx Tx) error {
-		v, err2 := tx.(*lmdbTx).tx.Get(dbi, key)
+		v, err2 := tx.(*lmdbTx).tx.Get(db.dbi(bucket), key)
 		if err2 != nil {
 			if lmdb.IsNotFound(err2) {
 				return nil
@@ -283,10 +276,12 @@ func (db *LmdbKV) Begin(ctx context.Context, writable bool) (Tx, error) {
 	}
 
 	tx.RawRead = true
+	tx.Pooled = false
 
 	t := lmdbKvTxPool.Get().(*lmdbTx)
 	t.ctx = ctx
 	t.tx = tx
+	t.db = db
 	return t, nil
 }
 
@@ -310,10 +305,6 @@ type lmdbCursor struct {
 	prefix []byte
 
 	cursor *lmdb.Cursor
-
-	k   []byte
-	v   []byte
-	err error
 }
 
 func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
@@ -323,8 +314,7 @@ func (db *LmdbKV) View(ctx context.Context, f func(tx Tx) error) (err error) {
 	t.db = db
 	return db.lmdbTxPool.View(func(tx *lmdb.Txn) error {
 		defer t.closeCursors()
-		tx.Pooled = true
-		tx.RawRead = true
+		tx.Pooled, tx.RawRead = true, true
 		t.tx = tx
 		return f(t)
 	})
@@ -351,8 +341,8 @@ func (tx *lmdbTx) Bucket(name []byte) Bucket {
 
 	b := lmdbKvBucketPool.Get().(*lmdbBucket)
 	b.tx = tx
-	b.dbi = tx.db.buckets[id]
 	b.id = id
+	b.dbi = tx.db.buckets[id]
 
 	// add to auto-close on end of transactions
 	if b.tx.buckets == nil {
@@ -412,12 +402,6 @@ func (c *lmdbCursor) NoValues() NoValuesCursor {
 }
 
 func (b lmdbBucket) Get(key []byte) (val []byte, err error) {
-	select {
-	case <-b.tx.ctx.Done():
-		return nil, b.tx.ctx.Err()
-	default:
-	}
-
 	val, err = b.tx.tx.Get(b.dbi, key)
 	if err != nil {
 		if lmdb.IsNotFound(err) {
@@ -468,19 +452,17 @@ func (b *lmdbBucket) Size() (uint64, error) {
 }
 
 func (b *lmdbBucket) Cursor() Cursor {
+	tx := b.tx
 	c := lmdbKvCursorPool.Get().(*lmdbCursor)
-	c.ctx = b.tx.ctx
+	c.ctx = tx.ctx
 	c.bucket = b
 	c.prefix = nil
-	c.k = nil
-	c.v = nil
-	c.err = nil
 	c.cursor = nil
 	// add to auto-close on end of transactions
-	if b.tx.cursors == nil {
-		b.tx.cursors = make([]*lmdbCursor, 0, 1)
+	if tx.cursors == nil {
+		tx.cursors = make([]*lmdbCursor, 0, 1)
 	}
-	b.tx.cursors = append(b.tx.cursors, c)
+	tx.cursors = append(tx.cursors, c)
 	return c
 }
 
@@ -521,13 +503,7 @@ func (c *lmdbCursor) First() ([]byte, []byte, error) {
 	return c.Seek(c.prefix)
 }
 
-func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, nil, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbCursor) Seek(seek []byte) (k, v []byte, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, nil, err
@@ -535,46 +511,46 @@ func (c *lmdbCursor) Seek(seek []byte) ([]byte, []byte, error) {
 	}
 
 	if seek == nil {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, v, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetRange)
+		k, v, err = c.cursor.Get(seek, nil, lmdb.SetRange)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", c.err, seek)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Seek(): %w, key: %x", err, seek)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) SeekTo(seek []byte) ([]byte, []byte, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbCursor) Next() ([]byte, []byte, error) {
+func (c *lmdbCursor) Next() (k, v []byte, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, nil, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
+	k, v, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
 			return nil, nil, nil
 		}
-		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", c.err)
+		return []byte{}, nil, fmt.Errorf("failed LmdbKV cursor.Next(): %w", err)
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, v = nil, nil
 	}
 
-	return c.k, c.v, nil
+	return k, v, nil
 }
 
 func (c *lmdbCursor) Delete(key []byte) error {
@@ -653,79 +629,76 @@ func (c *lmdbNoValuesCursor) Walk(walker func(k []byte, vSize uint32) (bool, err
 	return nil
 }
 
-func (c *lmdbNoValuesCursor) First() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) First() (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
+	var val []byte
 	if len(c.prefix) == 0 {
-		c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.First)
+		k, val, err = c.cursor.Get(nil, nil, lmdb.First)
 	} else {
-		c.k, c.v, c.err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
+		k, val, err = c.cursor.Get(c.prefix, nil, lmdb.SetKey)
 	}
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
 
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
-func (c *lmdbNoValuesCursor) Seek(seek []byte) ([]byte, uint32, error) {
-	select {
-	case <-c.ctx.Done():
-		return []byte{}, 0, c.ctx.Err()
-	default:
-	}
-
+func (c *lmdbNoValuesCursor) Seek(seek []byte) (k []byte, v uint32, err error) {
 	if c.cursor == nil {
 		if err := c.initCursor(); err != nil {
 			return []byte{}, 0, err
 		}
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(seek, nil, lmdb.SetKey)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(seek, nil, lmdb.SetKey)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
 
 func (c *lmdbNoValuesCursor) SeekTo(seek []byte) ([]byte, uint32, error) {
 	return c.Seek(seek)
 }
 
-func (c *lmdbNoValuesCursor) Next() ([]byte, uint32, error) {
+func (c *lmdbNoValuesCursor) Next() (k []byte, v uint32, err error) {
 	select {
 	case <-c.ctx.Done():
 		return []byte{}, 0, c.ctx.Err()
 	default:
 	}
 
-	c.k, c.v, c.err = c.cursor.Get(nil, nil, lmdb.Next)
-	if c.err != nil {
-		if lmdb.IsNotFound(c.err) {
-			return []byte{}, uint32(len(c.v)), nil
+	var val []byte
+	k, val, err = c.cursor.Get(nil, nil, lmdb.Next)
+	if err != nil {
+		if lmdb.IsNotFound(err) {
+			return []byte{}, uint32(len(val)), nil
 		}
-		return []byte{}, 0, c.err
+		return []byte{}, 0, err
 	}
-	if c.prefix != nil && !bytes.HasPrefix(c.k, c.prefix) {
-		c.k, c.v = nil, nil
+	if c.prefix != nil && !bytes.HasPrefix(k, c.prefix) {
+		k, val = nil, nil
 	}
 
-	return c.k, uint32(len(c.v)), c.err
+	return k, uint32(len(val)), err
 }
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index b1b318be1..e83b064fd 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -6,10 +6,14 @@ import (
 	"sort"
 	"sync"
 	"sync/atomic"
+	"time"
 
 	"github.com/ledgerwatch/turbo-geth/common"
+	"github.com/ledgerwatch/turbo-geth/metrics"
 )
 
+var fullBatchCommitTimer = metrics.NewRegisteredTimer("db/full_batch/commit_time", nil)
+
 type mutation struct {
 	puts   *puts // Map buckets to map[key]value
 	mu     sync.RWMutex
@@ -141,6 +145,12 @@ func (m *mutation) Delete(bucket, key []byte) error {
 }
 
 func (m *mutation) Commit() (uint64, error) {
+	if metrics.Enabled {
+		if m.db.IdealBatchSize() <= m.puts.Len() {
+			t := time.Now()
+			defer fullBatchCommitTimer.Update(time.Since(t))
+		}
+	}
 	if m.db == nil {
 		return 0, nil
 	}
diff --git a/ethdb/object_db.go b/ethdb/object_db.go
index 80b4fddfd..3f0b1bcc9 100644
--- a/ethdb/object_db.go
+++ b/ethdb/object_db.go
@@ -86,7 +86,7 @@ func (db *ObjectDatabase) MultiPut(tuples ...[]byte) (uint64, error) {
 }
 
 func (db *ObjectDatabase) Has(bucket, key []byte) (bool, error) {
-	if getter, ok := db.kv.(NativeHas); ok {
+	if getter, ok := db.kv.(NativeGet); ok {
 		return getter.Has(context.Background(), bucket, key)
 	}
 
@@ -108,10 +108,10 @@ func (db *ObjectDatabase) BucketsStat(ctx context.Context) (map[string]common.St
 }
 
 // Get returns the value for a given key if it's present.
-func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
+func (db *ObjectDatabase) Get(bucket, key []byte) (dat []byte, err error) {
 	// Retrieve the key and increment the miss counter if not found
 	if getter, ok := db.kv.(NativeGet); ok {
-		dat, err := getter.Get(context.Background(), bucket, key)
+		dat, err = getter.Get(context.Background(), bucket, key)
 		if err != nil {
 			return nil, err
 		}
@@ -121,8 +121,11 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		return dat, nil
 	}
 
-	var dat []byte
-	err := db.kv.View(context.Background(), func(tx Tx) error {
+	return db.get(bucket, key)
+}
+
+func (db *ObjectDatabase) get(bucket, key []byte) (dat []byte, err error) {
+	err = db.kv.View(context.Background(), func(tx Tx) error {
 		v, _ := tx.Bucket(bucket).Get(key)
 		if v != nil {
 			dat = make([]byte, len(v))
@@ -130,10 +133,13 @@ func (db *ObjectDatabase) Get(bucket, key []byte) ([]byte, error) {
 		}
 		return nil
 	})
+	if err != nil {
+		return nil, err
+	}
 	if dat == nil {
 		return nil, ErrKeyNotFound
 	}
-	return dat, err
+	return dat, nil
 }
 
 // GetIndexChunk returns proper index chunk or return error if index is not created.
diff --git a/ethdb/remote/kv_remote_client.go b/ethdb/remote/kv_remote_client.go
index a7543bf7c..a46876364 100644
--- a/ethdb/remote/kv_remote_client.go
+++ b/ethdb/remote/kv_remote_client.go
@@ -540,22 +540,22 @@ type Bucket struct {
 }
 
 type Cursor struct {
-	prefix         []byte
-	prefetchSize   uint
 	prefetchValues bool
+	initialized    bool
+	cursorHandle   uint64
+	prefetchSize   uint
+	cacheLastIdx   uint
+	cacheIdx       uint
+	prefix         []byte
 
 	ctx            context.Context
 	in             io.Reader
 	out            io.Writer
-	cursorHandle   uint64
-	cacheLastIdx   uint
-	cacheIdx       uint
 	cacheKeys      [][]byte
 	cacheValues    [][]byte
 	cacheValueSize []uint32
 
-	bucket      *Bucket
-	initialized bool
+	bucket *Bucket
 }
 
 func (c *Cursor) Prefix(v []byte) *Cursor {
diff --git a/ethdb/remote/remotechain/chain_remote.go b/ethdb/remote/remotechain/chain_remote.go
index c5aef0cb4..53d4451bd 100644
--- a/ethdb/remote/remotechain/chain_remote.go
+++ b/ethdb/remote/remotechain/chain_remote.go
@@ -4,12 +4,12 @@ import (
 	"bytes"
 	"encoding/binary"
 	"fmt"
-	"github.com/golang/snappy"
-	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"math/big"
 
+	"github.com/golang/snappy"
 	"github.com/ledgerwatch/turbo-geth/common"
 	"github.com/ledgerwatch/turbo-geth/common/dbutils"
+	"github.com/ledgerwatch/turbo-geth/common/debug"
 	"github.com/ledgerwatch/turbo-geth/common/hexutil"
 	"github.com/ledgerwatch/turbo-geth/core/types"
 	"github.com/ledgerwatch/turbo-geth/ethdb"
diff --git a/ethdb/remote/remotedbserver/server.go b/ethdb/remote/remotedbserver/server.go
index bff43ef68..fc04f51bb 100644
--- a/ethdb/remote/remotedbserver/server.go
+++ b/ethdb/remote/remotedbserver/server.go
@@ -73,6 +73,12 @@ func Server(ctx context.Context, db ethdb.KV, in io.Reader, out io.Writer, close
 	var seekKey []byte
 
 	for {
+		select {
+		case <-ctx.Done():
+			break
+		default:
+		}
+
 		// Make sure we are not blocking the resizing of the memory map
 		if tx != nil {
 			type Yieldable interface {
diff --git a/ethdb/remote/remotedbserver/server_test.go b/ethdb/remote/remotedbserver/server_test.go
index eb0e5a458..6be8e3ff0 100644
--- a/ethdb/remote/remotedbserver/server_test.go
+++ b/ethdb/remote/remotedbserver/server_test.go
@@ -49,7 +49,8 @@ const (
 )
 
 func TestCmdVersion(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -63,6 +64,8 @@ func TestCmdVersion(t *testing.T) {
 	// ---------- End of boilerplate code
 	assert.Nil(encoder.Encode(remote.CmdVersion), "Could not encode CmdVersion")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
 	require.NoError(err, "Error while calling Server")
 
@@ -75,7 +78,8 @@ func TestCmdVersion(t *testing.T) {
 }
 
 func TestCmdBeginEndError(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -97,6 +101,8 @@ func TestCmdBeginEndError(t *testing.T) {
 	// Second CmdEndTx
 	assert.Nil(encoder.Encode(remote.CmdEndTx), "Could not encode CmdEndTx")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -117,8 +123,8 @@ func TestCmdBeginEndError(t *testing.T) {
 }
 
 func TestCmdBucket(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
-
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
 	var inBuf bytes.Buffer
@@ -129,12 +135,14 @@ func TestCmdBucket(t *testing.T) {
 	decoder := codecpool.Decoder(&outBuf)
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBegin")
 
 	assert.Nil(encoder.Encode(remote.CmdBucket), "Could not encode CmdBucket")
 	assert.Nil(encoder.Encode(&name), "Could not encode name for CmdBucket")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -153,7 +161,8 @@ func TestCmdBucket(t *testing.T) {
 }
 
 func TestCmdGet(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -166,7 +175,7 @@ func TestCmdGet(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -187,6 +196,8 @@ func TestCmdGet(t *testing.T) {
 	assert.Nil(encoder.Encode(bucketHandle), "Could not encode bucketHandle for CmdGet")
 	assert.Nil(encoder.Encode(&key), "Could not encode key for CmdGet")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -216,7 +227,8 @@ func TestCmdGet(t *testing.T) {
 }
 
 func TestCmdSeek(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -229,7 +241,7 @@ func TestCmdSeek(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	assert.Nil(encoder.Encode(remote.CmdBeginTx), "Could not encode CmdBeginTx")
@@ -248,6 +260,9 @@ func TestCmdSeek(t *testing.T) {
 	assert.Nil(encoder.Encode(remote.CmdCursorSeek), "Could not encode CmdCursorSeek")
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandle for CmdCursorSeek")
 	assert.Nil(encoder.Encode(&seekKey), "Could not encode seekKey for CmdCursorSeek")
+
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -279,7 +294,8 @@ func TestCmdSeek(t *testing.T) {
 }
 
 func TestCursorOperations(t *testing.T) {
-	assert, require, ctx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(t), require.New(t), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 	// Prepare input buffer with one command CmdVersion
@@ -292,7 +308,7 @@ func TestCursorOperations(t *testing.T) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 
@@ -331,6 +347,8 @@ func TestCursorOperations(t *testing.T) {
 	assert.Nil(encoder.Encode(cursorHandle), "Could not encode cursorHandler for CmdCursorNext")
 	assert.Nil(encoder.Encode(numberOfKeys), "Could not encode numberOfKeys for CmdCursorNext")
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	err := Server(ctx, db.KV(), &inBuf, &outBuf, closer)
@@ -380,6 +398,7 @@ func TestCursorOperations(t *testing.T) {
 
 func TestTxYield(t *testing.T) {
 	assert, db := assert.New(t), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	errors := make(chan error, 10)
 	writeDoneNotify := make(chan struct{}, 1)
@@ -394,7 +413,7 @@ func TestTxYield(t *testing.T) {
 
 		// Long read-only transaction
 		if err := db.KV().View(context.Background(), func(tx ethdb.Tx) error {
-			b := tx.Bucket(dbutils.CurrentStateBucket)
+			b := tx.Bucket(dbutils.Buckets[0])
 			var keyBuf [8]byte
 			var i uint64
 			for {
@@ -424,7 +443,7 @@ func TestTxYield(t *testing.T) {
 
 	// Expand the database
 	err := db.KV().Update(context.Background(), func(tx ethdb.Tx) error {
-		b := tx.Bucket(dbutils.CurrentStateBucket)
+		b := tx.Bucket(dbutils.Buckets[0])
 		var keyBuf, valBuf [8]byte
 		for i := uint64(0); i < 10000; i++ {
 			binary.BigEndian.PutUint64(keyBuf[:], i)
@@ -448,7 +467,8 @@ func TestTxYield(t *testing.T) {
 }
 
 func BenchmarkRemoteCursorFirst(b *testing.B) {
-	assert, require, ctx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	assert, require, parentCtx, db := assert.New(b), require.New(b), context.Background(), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
 
@@ -462,12 +482,14 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 	defer codecpool.Return(decoder)
 	// ---------- End of boilerplate code
 	// Create a bucket and populate some values
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
 
+	ctx, cancel := context.WithCancel(parentCtx)
+	defer cancel()
 	// By now we constructed all input requests, now we call the
 	// Server to process them all
 	go func() {
@@ -528,9 +550,10 @@ func BenchmarkRemoteCursorFirst(b *testing.B) {
 
 func BenchmarkKVCursorFirst(b *testing.B) {
 	assert, require, db := assert.New(b), require.New(b), ethdb.NewMemDatabase()
+	defer db.Close()
 
 	// ---------- Start of boilerplate code
-	var name = dbutils.CurrentStateBucket
+	var name = dbutils.Buckets[0]
 	require.NoError(db.Put(name, []byte(key1), []byte(value1)))
 	require.NoError(db.Put(name, []byte(key2), []byte(value2)))
 	require.NoError(db.Put(name, []byte(key3), []byte(value3)))
