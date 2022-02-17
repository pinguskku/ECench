commit 8b97c5c620604c6f1de44e0cae097a8c2902445f
Author: ledgerwatch <akhounov@gmail.com>
Date:   Thu May 21 21:55:39 2020 +0100

    Remove memory leak caused by accountCache, count batch size in bytes (#565)
    
    * Lower cache sizes
    
    * Add memory profiling over http
    
    * No code cache
    
    * Calculate db batch size in bytes
    
    * Fixes
    
    * Fixes
    
    * Increase batch
    
    * Fix linter
    
    * Restore account caching, with copying
    
    * Reintroduce code cache
    
    * Add fixed overhead per key
    
    * Print batch size
    
    * Fix batch size
    
    * Reduce batch size
    
    * 50 Mb
    
    * Fix linter

diff --git a/cmd/geth/main.go b/cmd/geth/main.go
index a6af14006..1f9ab90e2 100644
--- a/cmd/geth/main.go
+++ b/cmd/geth/main.go
@@ -43,6 +43,10 @@ import (
 	"github.com/ledgerwatch/turbo-geth/log"
 	"github.com/ledgerwatch/turbo-geth/metrics"
 	"github.com/ledgerwatch/turbo-geth/node"
+
+	"net/http"
+	//nolint:gosec
+	_ "net/http/pprof"
 )
 
 const (
@@ -260,6 +264,9 @@ func init() {
 }
 
 func main() {
+	go func() {
+		log.Info("HTTP", "error", http.ListenAndServe("localhost:6060", nil))
+	}()
 	if err := app.Run(os.Args); err != nil {
 		fmt.Fprintln(os.Stderr, err)
 		os.Exit(1)
diff --git a/core/blockchain.go b/core/blockchain.go
index 5aaf75081..d6ca2d2ea 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1924,7 +1924,7 @@ func (st *insertStats) report(chain []*types.Block, index int, batch ethdb.DbWit
 		context := []interface{}{
 			"blocks", st.processed, "txs", txs, "mgas", float64(st.usedGas) / 1000000,
 			"elapsed", common.PrettyDuration(elapsed), "mgasps", float64(st.usedGas) * 1000 / float64(elapsed),
-			"number", end.Number(), "hash", end.Hash(), "batch", batch.BatchSize(),
+			"number", end.Number(), "hash", end.Hash(), "batch", common.StorageSize(batch.BatchSize()),
 		}
 		if timestamp := time.Unix(int64(end.Time()), 0); time.Since(timestamp) > time.Minute {
 			context = append(context, []interface{}{"age", common.PrettyAge(timestamp)}...)
diff --git a/core/state/db_state_reader.go b/core/state/db_state_reader.go
index c2a5b9b29..3e0c9e618 100644
--- a/core/state/db_state_reader.go
+++ b/core/state/db_state_reader.go
@@ -68,7 +68,7 @@ func (dbr *DbStateReader) ReadAccountData(address common.Address) (*accounts.Acc
 		return nil, nil
 	}
 	if dbr.accountCache != nil {
-		dbr.accountCache.Add(address, &a)
+		dbr.accountCache.Add(address, a.SelfCopy())
 	}
 	return &a, nil
 }
@@ -118,9 +118,12 @@ func (dbr *DbStateReader) ReadAccountCode(address common.Address, codeHash commo
 		}
 	}
 	code, err = dbr.db.Get(dbutils.CodeBucket, codeHash[:])
-	if dbr.codeCache != nil {
+	if dbr.codeCache != nil && len(code) <= 1024 {
 		dbr.codeCache.Add(address, code)
 	}
+	if dbr.codeSizeCache != nil {
+		dbr.codeSizeCache.Add(address, len(code))
+	}
 	return code, err
 }
 
diff --git a/core/state/db_state_writer.go b/core/state/db_state_writer.go
index 9b862b5cd..0050698e2 100644
--- a/core/state/db_state_writer.go
+++ b/core/state/db_state_writer.go
@@ -88,7 +88,7 @@ func (dsw *DbStateWriter) UpdateAccountData(ctx context.Context, address common.
 		return err
 	}
 	if dsw.accountCache != nil {
-		dsw.accountCache.Add(address, account)
+		dsw.accountCache.Add(address, account.SelfCopy())
 	}
 	return nil
 }
@@ -129,7 +129,7 @@ func (dsw *DbStateWriter) UpdateAccountCode(address common.Address, incarnation
 	if err := dsw.stateDb.Put(dbutils.ContractCodeBucket, dbutils.GenerateStoragePrefix(addrHash[:], incarnation), codeHash[:]); err != nil {
 		return err
 	}
-	if dsw.codeCache != nil {
+	if dsw.codeCache != nil && len(code) <= 1024 {
 		dsw.codeCache.Add(address, code)
 	}
 	if dsw.codeSizeCache != nil {
diff --git a/eth/downloader/stagedsync_stage_execute.go b/eth/downloader/stagedsync_stage_execute.go
index 765f11d42..6961077fb 100644
--- a/eth/downloader/stagedsync_stage_execute.go
+++ b/eth/downloader/stagedsync_stage_execute.go
@@ -28,13 +28,15 @@ type progressLogger struct {
 	timer    *time.Ticker
 	quit     chan struct{}
 	interval int
+	batch    ethdb.DbWithPendingMutations
 }
 
-func NewProgressLogger(intervalInSeconds int) *progressLogger {
+func NewProgressLogger(intervalInSeconds int, batch ethdb.DbWithPendingMutations) *progressLogger {
 	return &progressLogger{
 		timer:    time.NewTicker(time.Duration(intervalInSeconds) * time.Second),
 		quit:     make(chan struct{}),
 		interval: intervalInSeconds,
+		batch:    batch,
 	}
 }
 
@@ -46,7 +48,7 @@ func (l *progressLogger) Start(numberRef *uint64) {
 			speed := float64(now-prev) / float64(l.interval)
 			var m runtime.MemStats
 			runtime.ReadMemStats(&m)
-			log.Info("Executed blocks:", "currentBlock", now, "speed (blk/second)", speed,
+			log.Info("Executed blocks:", "currentBlock", now, "speed (blk/second)", speed, "state batch", common.StorageSize(l.batch.BatchSize()),
 				"alloc", int(m.Alloc/1024), "sys", int(m.Sys/1024), "numGC", int(m.NumGC))
 			prev = now
 		}
@@ -67,8 +69,8 @@ func (l *progressLogger) Stop() {
 	close(l.quit)
 }
 
-const StateBatchSize = 1000000
-const ChangeBatchSize = 1000
+const StateBatchSize = 50 * 1024 * 1024 // 50 Mb
+const ChangeBatchSize = 1024 * 2014     // 1 Mb
 
 func spawnExecuteBlocksStage(stateDB ethdb.Database, blockchain BlockChain) (uint64, error) {
 	lastProcessedBlockNumber, err := GetStageProgress(stateDB, Execution)
@@ -94,7 +96,7 @@ func spawnExecuteBlocksStage(stateDB ethdb.Database, blockchain BlockChain) (uin
 	stateBatch := stateDB.NewBatch()
 	changeBatch := stateDB.NewBatch()
 
-	progressLogger := NewProgressLogger(logInterval)
+	progressLogger := NewProgressLogger(logInterval, stateBatch)
 	progressLogger.Start(&nextBlockNumber)
 	defer progressLogger.Stop()
 
diff --git a/ethdb/bolt_db.go b/ethdb/bolt_db.go
index 2a5f75d75..816a34433 100644
--- a/ethdb/bolt_db.go
+++ b/ethdb/bolt_db.go
@@ -725,7 +725,7 @@ func (db *BoltDatabase) NewBatch() DbWithPendingMutations {
 
 // IdealBatchSize defines the size of the data batches should ideally add in one write.
 func (db *BoltDatabase) IdealBatchSize() int {
-	return 100 * 1024
+	return 50 * 1024 * 1024 // 50 Mb
 }
 
 // [TURBO-GETH] Freezer support (not implemented yet)
diff --git a/ethdb/mutation.go b/ethdb/mutation.go
index c5887c8f2..14f947ad7 100644
--- a/ethdb/mutation.go
+++ b/ethdb/mutation.go
@@ -11,7 +11,7 @@ import (
 )
 
 type mutation struct {
-	puts puts // Map buckets to map[key]value
+	puts *puts // Map buckets to map[key]value
 	mu   sync.RWMutex
 	db   Database
 }
diff --git a/ethdb/mutation_puts.go b/ethdb/mutation_puts.go
index 83122af41..5413b1013 100644
--- a/ethdb/mutation_puts.go
+++ b/ethdb/mutation_puts.go
@@ -1,29 +1,35 @@
 package ethdb
 
-import (
-)
-
 type puts struct {
-	mp       map[string]putsBucket //map[bucket]putsBucket
+	mp   map[string]putsBucket //map[bucket]putsBucket
+	size int
 }
 
-func newPuts() puts {
-	return puts{
-		mp:       make(map[string]putsBucket),
+func newPuts() *puts {
+	return &puts{
+		mp:   make(map[string]putsBucket),
+		size: 0,
 	}
 }
 
-func (p puts) set(bucket, key, value []byte) {
+func (p *puts) set(bucket, key, value []byte) {
 	var bucketPuts putsBucket
 	var ok bool
 	if bucketPuts, ok = p.mp[string(bucket)]; !ok {
 		bucketPuts = make(putsBucket)
 		p.mp[string(bucket)] = bucketPuts
 	}
+	skey := string(key)
+	if oldVal, ok := bucketPuts[skey]; ok {
+		p.size -= len(oldVal)
+	} else {
+		p.size += len(skey) + 32 // Add fixed overhead per key
+	}
 	bucketPuts[string(key)] = value
+	p.size += len(value)
 }
 
-func (p puts) get(bucket, key []byte) ([]byte, bool) {
+func (p *puts) get(bucket, key []byte) ([]byte, bool) {
 	var bucketPuts putsBucket
 	var ok bool
 	if bucketPuts, ok = p.mp[string(bucket)]; !ok {
@@ -32,16 +38,12 @@ func (p puts) get(bucket, key []byte) ([]byte, bool) {
 	return bucketPuts.Get(key)
 }
 
-func (p puts) Delete(bucket, key []byte) {
+func (p *puts) Delete(bucket, key []byte) {
 	p.set(bucket, key, nil)
 }
 
-func (p puts) Size() int {
-	var size int
-	for _, put := range p.mp {
-		size += len(put)
-	}
-	return size
+func (p *puts) Size() int {
+	return p.size
 }
 
 type putsBucket map[string][]byte //map[key]value
@@ -71,4 +73,3 @@ func (pb putsBucket) GetStr(key string) ([]byte, bool) {
 
 	return value, true
 }
-
