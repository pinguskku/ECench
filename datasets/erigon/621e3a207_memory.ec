commit 621e3a207410560481f45ddb7e8f34d5da8ef7bd
Author: Alex Sharov <AskAlexSharov@gmail.com>
Date:   Tue Jul 21 08:58:00 2020 +0700

    Ci lmdb - reduce memory usage  (#762)

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 91075c48b..0876b2701 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -38,11 +38,15 @@ import (
 	"github.com/ledgerwatch/turbo-geth/params"
 )
 
+const OwerwriteBlockCacheItems = 1024
+const OwerwriteMaxForkAncestry = 3000
+
 // Reduce some of the parameters to make the tester faster.
 func init() {
-	maxForkAncestry = 10000
-	blockCacheItems = 1024
-	fsHeaderContCheck = 500 * time.Millisecond
+	maxForkAncestry = OwerwriteMaxForkAncestry
+	blockCacheItems = OwerwriteBlockCacheItems
+	fsHeaderSafetyNet = 256
+	fsHeaderContCheck = 50 * time.Millisecond
 }
 
 // downloadTester is a test simulator for mocking out local block chain.
@@ -1020,7 +1024,7 @@ func testInvalidHeaderRollback(t *testing.T, protocol int, mode SyncMode) {
 	defer tester.peerDb.Close()
 
 	// Create a small enough block chain to download
-	targetBlocks := 3*fsHeaderSafetyNet + 256 + fsMinFullBlocks
+	targetBlocks := 2*fsHeaderSafetyNet + 256 + fsMinFullBlocks
 	chain := testChainBase.shorten(targetBlocks)
 
 	// Attempt to sync with an attacker that feeds junk during the fast sync phase.
@@ -1040,7 +1044,7 @@ func testInvalidHeaderRollback(t *testing.T, protocol int, mode SyncMode) {
 	// Attempt to sync with an attacker that feeds junk during the block import phase.
 	// This should result in both the last fsHeaderSafetyNet number of headers being
 	// rolled back, and also the pivot point being reverted to a non-block status.
-	missing = 3*fsHeaderSafetyNet + MaxHeaderFetch + 1
+	missing = 2*fsHeaderSafetyNet + MaxHeaderFetch + 1
 	blockAttackChain := chain.shorten(chain.len())
 	delete(fastAttackChain.headerm, fastAttackChain.chain[missing]) // Make sure the fast-attacker doesn't fill in
 	delete(blockAttackChain.headerm, blockAttackChain.chain[missing])
diff --git a/eth/downloader/testchain_test.go b/eth/downloader/testchain_test.go
index da7bae7b8..619ea025a 100644
--- a/eth/downloader/testchain_test.go
+++ b/eth/downloader/testchain_test.go
@@ -43,13 +43,13 @@ var (
 )
 
 // The common prefix of all test chains:
-var testChainBase = newTestChain(blockCacheItems+200, testDb, testGenesis)
+var testChainBase = newTestChain(OwerwriteBlockCacheItems+200, testDb, testGenesis)
 
 // Different forks on top of the base chain:
 var testChainForkLightA, testChainForkLightB, testChainForkHeavy *testChain
 
 func TestMain(m *testing.M) {
-	var forkLen = int(maxForkAncestry + 50)
+	var forkLen = OwerwriteMaxForkAncestry + 50
 	var wg sync.WaitGroup
 	wg.Add(3)
 	go func() { testChainForkLightA = testChainBase.makeFork(forkLen, false, 1); wg.Done() }()
diff --git a/ethdb/kv_lmdb.go b/ethdb/kv_lmdb.go
index 279babb89..25d2cae6e 100644
--- a/ethdb/kv_lmdb.go
+++ b/ethdb/kv_lmdb.go
@@ -50,7 +50,7 @@ func (opts lmdbOpts) Open() (KV, error) {
 	var logger log.Logger
 
 	if opts.inMem {
-		err = env.SetMapSize(64 << 20) // 64MB
+		err = env.SetMapSize(32 << 20) // 32MB
 		logger = log.New("lmdb", "inMem")
 		if err != nil {
 			return nil, err
