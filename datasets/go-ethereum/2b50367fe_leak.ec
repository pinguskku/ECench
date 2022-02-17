commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
commit 2b50367fe938e603a5f9d3a525e0cdfa000f402e
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 7 15:47:25 2017 +0300

    core: fix blockchain goroutine leaks in tests

diff --git a/core/bench_test.go b/core/bench_test.go
index 20676fc97..b9250f7d3 100644
--- a/core/bench_test.go
+++ b/core/bench_test.go
@@ -300,6 +300,7 @@ func benchReadChain(b *testing.B, full bool, count uint64) {
 			}
 		}
 
+		chain.Stop()
 		db.Close()
 	}
 }
diff --git a/core/block_validator_test.go b/core/block_validator_test.go
index abe1766b4..c0afc2955 100644
--- a/core/block_validator_test.go
+++ b/core/block_validator_test.go
@@ -44,6 +44,7 @@ func TestHeaderVerification(t *testing.T) {
 	}
 	// Run the header checker for blocks one-by-one, checking for both valid and invalid nonces
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
 
 	for i := 0; i < len(blocks); i++ {
 		for j, valid := range []bool{true, false} {
@@ -108,9 +109,11 @@ func testHeaderConcurrentVerification(t *testing.T, threads int) {
 		if valid {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		} else {
 			chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeFailer(uint64(len(headers)-1)), new(event.TypeMux), vm.Config{})
 			_, results = chain.engine.VerifyHeaders(chain, headers, seals)
+			chain.Stop()
 		}
 		// Wait for all the verification results
 		checks := make(map[int]error)
@@ -172,6 +175,8 @@ func testHeaderConcurrentAbortion(t *testing.T, threads int) {
 
 	// Start the verifications and immediately abort
 	chain, _ := NewBlockChain(testdb, params.TestChainConfig, ethash.NewFakeDelayer(time.Millisecond), new(event.TypeMux), vm.Config{})
+	defer chain.Stop()
+
 	abort, results := chain.engine.VerifyHeaders(chain, headers, seals)
 	close(abort)
 
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 5fa671e2b..4a0f44940 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -20,6 +20,7 @@ import (
 	"fmt"
 	"math/big"
 	"math/rand"
+	"sync"
 	"testing"
 	"time"
 
@@ -61,6 +62,8 @@ func testFork(t *testing.T, blockchain *BlockChain, i, n int, full bool, compara
 	if err != nil {
 		t.Fatal("could not make new canonical in testFork", err)
 	}
+	defer blockchain2.Stop()
+
 	// Assert the chains have the same header/block at #i
 	var hash1, hash2 common.Hash
 	if full {
@@ -182,6 +185,8 @@ func insertChain(done chan bool, blockchain *BlockChain, chain types.Blocks, t *
 
 func TestLastBlock(t *testing.T) {
 	bchain := newTestBlockChain(false)
+	defer bchain.Stop()
+
 	block := makeBlockChain(bchain.CurrentBlock(), 1, bchain.chainDb, 0)[0]
 	bchain.insert(block)
 	if block.Hash() != GetHeadBlockHash(bchain.chainDb) {
@@ -202,6 +207,8 @@ func testExtendCanonical(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -228,6 +235,8 @@ func testShorterFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	worse := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) >= 0 {
@@ -256,6 +265,8 @@ func testLongerFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	better := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) <= 0 {
@@ -284,6 +295,8 @@ func testEqualFork(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer processor.Stop()
+
 	// Define the difficulty comparator
 	equal := func(td1, td2 *big.Int) {
 		if td2.Cmp(td1) != 0 {
@@ -309,6 +322,8 @@ func testBrokenChain(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to make new canonical chain: %v", err)
 	}
+	defer blockchain.Stop()
+
 	// Create a forked chain, and try to insert with a missing link
 	if full {
 		chain := makeBlockChain(blockchain.CurrentBlock(), 5, db, forkSeed)[1:]
@@ -385,6 +400,7 @@ func testReorgShort(t *testing.T, full bool) {
 
 func testReorg(t *testing.T, first, second []int, td int64, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Insert an easy and a difficult chain afterwards
 	if full {
@@ -429,6 +445,7 @@ func TestBadBlockHashes(t *testing.T)  { testBadHashes(t, true) }
 
 func testBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, ban a hash and try to import
 	var err error
@@ -453,6 +470,7 @@ func TestReorgBadBlockHashes(t *testing.T)  { testReorgBadHashes(t, true) }
 
 func testReorgBadHashes(t *testing.T, full bool) {
 	bc := newTestBlockChain(true)
+	defer bc.Stop()
 
 	// Create a chain, import and ban afterwards
 	headers := makeHeaderChainWithDiff(bc.genesisBlock, []int{1, 2, 3, 4}, 10)
@@ -483,6 +501,8 @@ func testReorgBadHashes(t *testing.T, full bool) {
 	if err != nil {
 		t.Fatalf("failed to create new chain manager: %v", err)
 	}
+	defer ncm.Stop()
+
 	if full {
 		if ncm.CurrentBlock().Hash() != blocks[2].Header().Hash() {
 			t.Errorf("last block hash mismatch: have: %x, want %x", ncm.CurrentBlock().Hash(), blocks[2].Header().Hash())
@@ -508,6 +528,8 @@ func testInsertNonceError(t *testing.T, full bool) {
 		if err != nil {
 			t.Fatalf("failed to create pristine chain: %v", err)
 		}
+		defer blockchain.Stop()
+
 		// Create and insert a chain with a failing nonce
 		var (
 			failAt  int
@@ -589,15 +611,16 @@ func TestFastVsFullChains(t *testing.T) {
 	archiveDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(archiveDb)
 	archive, _ := NewBlockChain(archiveDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer archive.Stop()
 
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
-
 	// Fast import the chain as a non-archive node to test
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -678,6 +701,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := archive.InsertChain(blocks); err != nil {
 		t.Fatalf("failed to process block %d: %v", n, err)
 	}
+	defer archive.Stop()
+
 	assert(t, "archive", archive, height, height, height)
 	archive.Rollback(remove)
 	assert(t, "archive", archive, height/2, height/2, height/2)
@@ -686,6 +711,7 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	fastDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(fastDb)
 	fast, _ := NewBlockChain(fastDb, gspec.Config, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer fast.Stop()
 
 	headers := make([]*types.Header, len(blocks))
 	for i, block := range blocks {
@@ -709,6 +735,8 @@ func TestLightVsFastVsFullChainHeads(t *testing.T) {
 	if n, err := light.InsertHeaderChain(headers, 1); err != nil {
 		t.Fatalf("failed to insert header %d: %v", n, err)
 	}
+	defer light.Stop()
+
 	assert(t, "light", light, height, 0, 0)
 	light.Rollback(remove)
 	assert(t, "light", light, height/2, 0, 0)
@@ -777,6 +805,7 @@ func TestChainTxReorgs(t *testing.T) {
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		t.Fatalf("failed to insert original chain[%d]: %v", i, err)
 	}
+	defer blockchain.Stop()
 
 	// overwrite the old chain
 	chain, _ = GenerateChain(gspec.Config, genesis, db, 5, func(i int, gen *BlockGen) {
@@ -845,6 +874,7 @@ func TestLogReorgs(t *testing.T) {
 
 	var evmux event.TypeMux
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	subs := evmux.Subscribe(RemovedLogsEvent{})
 	chain, _ := GenerateChain(params.TestChainConfig, genesis, db, 2, func(i int, gen *BlockGen) {
@@ -886,6 +916,7 @@ func TestReorgSideEvent(t *testing.T) {
 
 	evmux := &event.TypeMux{}
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
 
 	chain, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, gen *BlockGen) {})
 	if _, err := blockchain.InsertChain(chain); err != nil {
@@ -955,11 +986,18 @@ done:
 
 // Tests if the canonical block can be fetched from the database during chain insertion.
 func TestCanonicalBlockRetrieval(t *testing.T) {
-	bc := newTestBlockChain(false)
+	bc := newTestBlockChain(true)
+	defer bc.Stop()
+
 	chain, _ := GenerateChain(bc.config, bc.genesisBlock, bc.chainDb, 10, func(i int, gen *BlockGen) {})
 
+	var pend sync.WaitGroup
+	pend.Add(len(chain))
+
 	for i := range chain {
 		go func(block *types.Block) {
+			defer pend.Done()
+
 			// try to retrieve a block by its canonical hash and see if the block data can be retrieved.
 			for {
 				ch := GetCanonicalHash(bc.chainDb, block.NumberU64())
@@ -980,8 +1018,11 @@ func TestCanonicalBlockRetrieval(t *testing.T) {
 			}
 		}(chain[i])
 
-		bc.InsertChain(types.Blocks{chain[i]})
+		if _, err := bc.InsertChain(types.Blocks{chain[i]}); err != nil {
+			t.Fatalf("failed to insert block %d: %v", i, err)
+		}
 	}
+	pend.Wait()
 }
 
 func TestEIP155Transition(t *testing.T) {
@@ -1001,6 +1042,8 @@ func TestEIP155Transition(t *testing.T) {
 	)
 
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 4, func(i int, block *BlockGen) {
 		var (
 			tx      *types.Transaction
@@ -1104,10 +1147,12 @@ func TestEIP161AccountRemoval(t *testing.T) {
 			},
 			Alloc: GenesisAlloc{address: {Balance: funds}},
 		}
-		genesis       = gspec.MustCommit(db)
-		mux           event.TypeMux
-		blockchain, _ = NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+		genesis = gspec.MustCommit(db)
+		mux     event.TypeMux
 	)
+	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), &mux, vm.Config{})
+	defer blockchain.Stop()
+
 	blocks, _ := GenerateChain(gspec.Config, genesis, db, 3, func(i int, block *BlockGen) {
 		var (
 			tx     *types.Transaction
diff --git a/core/chain_makers_test.go b/core/chain_makers_test.go
index 3a7c62396..28eb76c63 100644
--- a/core/chain_makers_test.go
+++ b/core/chain_makers_test.go
@@ -81,7 +81,10 @@ func ExampleGenerateChain() {
 
 	// Import the chain. This runs all block validation rules.
 	evmux := &event.TypeMux{}
+
 	blockchain, _ := NewBlockChain(db, gspec.Config, ethash.NewFaker(), evmux, vm.Config{})
+	defer blockchain.Stop()
+
 	if i, err := blockchain.InsertChain(chain); err != nil {
 		fmt.Printf("insert error (block %d): %v\n", chain[i].NumberU64(), err)
 		return
diff --git a/core/dao_test.go b/core/dao_test.go
index bc9f3f394..99bf1ecae 100644
--- a/core/dao_test.go
+++ b/core/dao_test.go
@@ -43,11 +43,13 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	gspec.MustCommit(proDb)
 	proConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: true}
 	proBc, _ := NewBlockChain(proDb, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer proBc.Stop()
 
 	conDb, _ := ethdb.NewMemDatabase()
 	gspec.MustCommit(conDb)
 	conConf := &params.ChainConfig{HomesteadBlock: big.NewInt(0), DAOForkBlock: forkBlock, DAOForkSupport: false}
 	conBc, _ := NewBlockChain(conDb, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer conBc.Stop()
 
 	if _, err := proBc.InsertChain(prefix); err != nil {
 		t.Fatalf("pro-fork: failed to import chain prefix: %v", err)
@@ -60,7 +62,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a pro-fork block, and try to feed into the no-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -81,7 +85,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 		// Create a no-fork block, and try to feed into the pro-fork chain
 		db, _ = ethdb.NewMemDatabase()
 		gspec.MustCommit(db)
+
 		bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+		defer bc.Stop()
 
 		blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 		for j := 0; j < len(blocks)/2; j++ {
@@ -103,7 +109,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that contra-forkers accept pro-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ := NewBlockChain(db, conConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks := conBc.GetBlocksFromHash(conBc.CurrentBlock().Hash(), int(conBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
@@ -119,7 +127,9 @@ func TestDAOForkRangeExtradata(t *testing.T) {
 	// Verify that pro-forkers accept contra-fork extra-datas after forking finishes
 	db, _ = ethdb.NewMemDatabase()
 	gspec.MustCommit(db)
+
 	bc, _ = NewBlockChain(db, proConf, ethash.NewFaker(), new(event.TypeMux), vm.Config{})
+	defer bc.Stop()
 
 	blocks = proBc.GetBlocksFromHash(proBc.CurrentBlock().Hash(), int(proBc.CurrentBlock().NumberU64()))
 	for j := 0; j < len(blocks)/2; j++ {
diff --git a/core/filter_test.go b/core/filter_test.go
deleted file mode 100644
index 58e71e305..000000000
--- a/core/filter_test.go
+++ /dev/null
@@ -1,17 +0,0 @@
-// Copyright 2014 The go-ethereum Authors
-// This file is part of the go-ethereum library.
-//
-// The go-ethereum library is free software: you can redistribute it and/or modify
-// it under the terms of the GNU Lesser General Public License as published by
-// the Free Software Foundation, either version 3 of the License, or
-// (at your option) any later version.
-//
-// The go-ethereum library is distributed in the hope that it will be useful,
-// but WITHOUT ANY WARRANTY; without even the implied warranty of
-// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
-// GNU Lesser General Public License for more details.
-//
-// You should have received a copy of the GNU Lesser General Public License
-// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
-
-package core
diff --git a/core/genesis_test.go b/core/genesis_test.go
index bc82fe54e..8b193759f 100644
--- a/core/genesis_test.go
+++ b/core/genesis_test.go
@@ -120,6 +120,8 @@ func TestSetupGenesis(t *testing.T) {
 				// Advance to block #4, past the homestead transition block of customg.
 				genesis := oldcustomg.MustCommit(db)
 				bc, _ := NewBlockChain(db, oldcustomg.Config, ethash.NewFullFaker(), new(event.TypeMux), vm.Config{})
+				defer bc.Stop()
+
 				bc.SetValidator(bproc{})
 				bc.InsertChain(makeBlockChainWithDiff(genesis, []int{2, 3, 4, 5}, 0))
 				bc.CurrentBlock()
diff --git a/core/tx_pool_test.go b/core/tx_pool_test.go
index 9a03caf61..020d6bedd 100644
--- a/core/tx_pool_test.go
+++ b/core/tx_pool_test.go
@@ -235,6 +235,8 @@ func TestTransactionQueue(t *testing.T) {
 	}
 
 	pool, key = setupTxPool()
+	defer pool.Stop()
+
 	tx1 := transaction(0, big.NewInt(100), key)
 	tx2 := transaction(10, big.NewInt(100), key)
 	tx3 := transaction(11, big.NewInt(100), key)
@@ -848,6 +850,8 @@ func TestTransactionPendingLimitingEquivalency(t *testing.T) { testTransactionLi
 func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	// Add a batch of transactions to a pool one by one
 	pool1, key1 := setupTxPool()
+	defer pool1.Stop()
+
 	account1, _ := deriveSender(transaction(0, big.NewInt(0), key1))
 	state1, _ := pool1.currentState()
 	state1.AddBalance(account1, big.NewInt(1000000))
@@ -859,6 +863,8 @@ func testTransactionLimitingEquivalency(t *testing.T, origin uint64) {
 	}
 	// Add a batch of transactions to a pool in one big batch
 	pool2, key2 := setupTxPool()
+	defer pool2.Stop()
+
 	account2, _ := deriveSender(transaction(0, big.NewInt(0), key2))
 	state2, _ := pool2.currentState()
 	state2.AddBalance(account2, big.NewInt(1000000))
@@ -1356,6 +1362,7 @@ func testTransactionJournaling(t *testing.T, nolocals bool) {
 	if err := validateTxPoolInternals(pool); err != nil {
 		t.Fatalf("pool internal state corrupted: %v", err)
 	}
+	pool.Stop()
 }
 
 // Benchmarks the speed of validating the contents of the pending queue of the
