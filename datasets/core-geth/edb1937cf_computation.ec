commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
commit edb1937cf78b2562edc0e62cf369fc7886bb224f
Author: Martin Holst Swende <martin@swende.se>
Date:   Thu Oct 7 15:47:50 2021 +0200

    core: improve shutdown synchronization in BlockChain (#22853)
    
    This change removes misuses of sync.WaitGroup in BlockChain. Before this change,
    block insertion modified the WaitGroup counter in order to ensure that Stop would wait
    for pending operations to complete. This was racy and could even lead to crashes
    if Stop was called at an unfortunate time. The issue is resolved by adding a specialized
    'closable' mutex, which prevents chain modifications after stopping while also
    synchronizing writers with each other.
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/core/blockchain.go b/core/blockchain.go
index 66bc395c9..559800a06 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -39,6 +39,7 @@ import (
 	"github.com/ethereum/go-ethereum/core/vm"
 	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/event"
+	"github.com/ethereum/go-ethereum/internal/syncx"
 	"github.com/ethereum/go-ethereum/log"
 	"github.com/ethereum/go-ethereum/metrics"
 	"github.com/ethereum/go-ethereum/params"
@@ -80,6 +81,7 @@ var (
 	blockPrefetchInterruptMeter = metrics.NewRegisteredMeter("chain/prefetch/interrupts", nil)
 
 	errInsertionInterrupted = errors.New("insertion is interrupted")
+	errChainStopped         = errors.New("blockchain is stopped")
 )
 
 const (
@@ -183,7 +185,9 @@ type BlockChain struct {
 	scope         event.SubscriptionScope
 	genesisBlock  *types.Block
 
-	chainmu sync.RWMutex // blockchain insertion lock
+	// This mutex synchronizes chain write operations.
+	// Readers don't need to take it, they can just read the database.
+	chainmu *syncx.ClosableMutex
 
 	currentBlock     atomic.Value // Current head of the block chain
 	currentFastBlock atomic.Value // Current head of the fast-sync chain (may be above the block chain!)
@@ -196,8 +200,8 @@ type BlockChain struct {
 	txLookupCache *lru.Cache     // Cache for the most recent transaction lookup data.
 	futureBlocks  *lru.Cache     // future blocks are blocks added for later processing
 
-	quit          chan struct{}  // blockchain quit channel
-	wg            sync.WaitGroup // chain processing wait group for shutting down
+	wg            sync.WaitGroup //
+	quit          chan struct{}  // shutdown signal, closed in Stop.
 	running       int32          // 0 if chain is running, 1 when stopped
 	procInterrupt int32          // interrupt signaler for block processing
 
@@ -235,6 +239,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			Preimages: cacheConfig.Preimages,
 		}),
 		quit:           make(chan struct{}),
+		chainmu:        syncx.NewClosableMutex(),
 		shouldPreserve: shouldPreserve,
 		bodyCache:      bodyCache,
 		bodyRLPCache:   bodyRLPCache,
@@ -278,6 +283,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 	if err := bc.loadLastState(); err != nil {
 		return nil, err
 	}
+
 	// Make sure the state associated with the block is available
 	head := bc.CurrentBlock()
 	if _, err := state.New(head.Root(), bc.stateCache, bc.snaps); err != nil {
@@ -306,6 +312,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Ensure that a previous crash in SetHead doesn't leave extra ancients
 	if frozen, err := bc.db.Ancients(); err == nil && frozen > 0 {
 		var (
@@ -357,6 +364,7 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 			}
 		}
 	}
+
 	// Load any existing snapshot, regenerating it if loading failed
 	if bc.cacheConfig.SnapshotLimit > 0 {
 		// If the chain was rewound past the snapshot persistent layer (causing
@@ -372,14 +380,19 @@ func NewBlockChain(db ethdb.Database, cacheConfig *CacheConfig, chainConfig *par
 		}
 		bc.snaps, _ = snapshot.New(bc.db, bc.stateCache.TrieDB(), bc.cacheConfig.SnapshotLimit, head.Root(), !bc.cacheConfig.SnapshotWait, true, recover)
 	}
-	// Take ownership of this particular state
-	go bc.update()
+
+	// Start future block processor.
+	bc.wg.Add(1)
+	go bc.futureBlocksLoop()
+
+	// Start tx indexer/unindexer.
 	if txLookupLimit != nil {
 		bc.txLookupLimit = *txLookupLimit
 
 		bc.wg.Add(1)
 		go bc.maintainTxIndex(txIndexBlock)
 	}
+
 	// If periodic cache journal is required, spin it up.
 	if bc.cacheConfig.TrieCleanRejournal > 0 {
 		if bc.cacheConfig.TrieCleanRejournal < time.Minute {
@@ -488,7 +501,9 @@ func (bc *BlockChain) SetHead(head uint64) error {
 //
 // The method returns the block number where the requested root cap was found.
 func (bc *BlockChain) SetHeadBeyondRoot(head uint64, root common.Hash) (uint64, error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Track the block number of the requested root hash
@@ -633,8 +648,11 @@ func (bc *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if _, err := trie.NewSecure(block.Root(), bc.stateCache.TrieDB()); err != nil {
 		return err
 	}
-	// If all checks out, manually set the head block
-	bc.chainmu.Lock()
+
+	// If all checks out, manually set the head block.
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	bc.currentBlock.Store(block)
 	headBlockGauge.Update(int64(block.NumberU64()))
 	bc.chainmu.Unlock()
@@ -707,7 +725,9 @@ func (bc *BlockChain) ResetWithGenesisBlock(genesis *types.Block) error {
 	if err := bc.SetHead(0); err != nil {
 		return err
 	}
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
 	defer bc.chainmu.Unlock()
 
 	// Prepare the genesis block and reinitialise the chain
@@ -737,8 +757,10 @@ func (bc *BlockChain) Export(w io.Writer) error {
 
 // ExportN writes a subset of the active chain to the given writer.
 func (bc *BlockChain) ExportN(w io.Writer, first uint64, last uint64) error {
-	bc.chainmu.RLock()
-	defer bc.chainmu.RUnlock()
+	if !bc.chainmu.TryLock() {
+		return errChainStopped
+	}
+	defer bc.chainmu.Unlock()
 
 	if first > last {
 		return fmt.Errorf("export failed: first (%d) is greater than last (%d)", first, last)
@@ -991,10 +1013,21 @@ func (bc *BlockChain) Stop() {
 	if !atomic.CompareAndSwapInt32(&bc.running, 0, 1) {
 		return
 	}
-	// Unsubscribe all subscriptions registered from blockchain
+
+	// Unsubscribe all subscriptions registered from blockchain.
 	bc.scope.Close()
+
+	// Signal shutdown to all goroutines.
 	close(bc.quit)
 	bc.StopInsert()
+
+	// Now wait for all chain modifications to end and persistent goroutines to exit.
+	//
+	// Note: Close waits for the mutex to become available, i.e. any running chain
+	// modification will have exited when Close returns. Since we also called StopInsert,
+	// the mutex should become available quickly. It cannot be taken again after Close has
+	// returned.
+	bc.chainmu.Close()
 	bc.wg.Wait()
 
 	// Ensure that the entirety of the state snapshot is journalled to disk.
@@ -1005,6 +1038,7 @@ func (bc *BlockChain) Stop() {
 			log.Error("Failed to journal state snapshot", "err", err)
 		}
 	}
+
 	// Ensure the state of a recent block is also stored to disk before exiting.
 	// We're writing three different states to catch different restart scenarios:
 	//  - HEAD:     So we don't need to reprocess any blocks in the general case
@@ -1128,7 +1162,9 @@ func (bc *BlockChain) InsertReceiptChain(blockChain types.Blocks, receiptChain [
 	// updateHead updates the head fast sync block if the inserted blocks are better
 	// and returns an indicator whether the inserted blocks are canonical.
 	updateHead := func(head *types.Block) bool {
-		bc.chainmu.Lock()
+		if !bc.chainmu.TryLock() {
+			return false
+		}
 		defer bc.chainmu.Unlock()
 
 		// Rewind may have occurred, skip in that case.
@@ -1372,8 +1408,9 @@ var lastWrite uint64
 // but does not write any state. This is used to construct competing side forks
 // up to the point where they exceed the canonical total difficulty.
 func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return errInsertionInterrupted
+	}
 
 	batch := bc.db.NewBatch()
 	rawdb.WriteTd(batch, block.Hash(), block.NumberU64(), td)
@@ -1387,9 +1424,6 @@ func (bc *BlockChain) writeBlockWithoutState(block *types.Block, td *big.Int) (e
 // writeKnownBlock updates the head block flag with a known block
 // and introduces chain reorg if necessary.
 func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
-
 	current := bc.CurrentBlock()
 	if block.ParentHash() != current.Hash() {
 		if err := bc.reorg(current, block); err != nil {
@@ -1402,17 +1436,19 @@ func (bc *BlockChain) writeKnownBlock(block *types.Block) error {
 
 // WriteBlockWithState writes the block and all associated state to the database.
 func (bc *BlockChain) WriteBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return NonStatTy, errInsertionInterrupted
+	}
 	defer bc.chainmu.Unlock()
-
 	return bc.writeBlockWithState(block, receipts, logs, state, emitHeadEvent)
 }
 
 // writeBlockWithState writes the block and all associated state to the database,
 // but is expects the chain mutex to be held.
 func (bc *BlockChain) writeBlockWithState(block *types.Block, receipts []*types.Receipt, logs []*types.Log, state *state.StateDB, emitHeadEvent bool) (status WriteStatus, err error) {
-	bc.wg.Add(1)
-	defer bc.wg.Done()
+	if bc.insertStopped() {
+		return NonStatTy, errInsertionInterrupted
+	}
 
 	// Calculate the total difficulty of the block
 	ptd := bc.GetTd(block.ParentHash(), block.NumberU64()-1)
@@ -1576,31 +1612,28 @@ func (bc *BlockChain) InsertChain(chain types.Blocks) (int, error) {
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Remove already known canon-blocks
-	var (
-		block, prev *types.Block
-	)
-	// Do a sanity check that the provided chain is actually ordered and linked
+	// Do a sanity check that the provided chain is actually ordered and linked.
 	for i := 1; i < len(chain); i++ {
-		block = chain[i]
-		prev = chain[i-1]
+		block, prev := chain[i], chain[i-1]
 		if block.NumberU64() != prev.NumberU64()+1 || block.ParentHash() != prev.Hash() {
-			// Chain broke ancestry, log a message (programming error) and skip insertion
-			log.Error("Non contiguous block insert", "number", block.Number(), "hash", block.Hash(),
-				"parent", block.ParentHash(), "prevnumber", prev.Number(), "prevhash", prev.Hash())
-
+			log.Error("Non contiguous block insert",
+				"number", block.Number(),
+				"hash", block.Hash(),
+				"parent", block.ParentHash(),
+				"prevnumber", prev.Number(),
+				"prevhash", prev.Hash(),
+			)
 			return 0, fmt.Errorf("non contiguous insert: item %d is #%d [%x..], item %d is #%d [%x..] (parent [%x..])", i-1, prev.NumberU64(),
 				prev.Hash().Bytes()[:4], i, block.NumberU64(), block.Hash().Bytes()[:4], block.ParentHash().Bytes()[:4])
 		}
 	}
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(chain, true)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
 
-	return n, err
+	// Pre-check passed, start the full block imports.
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(chain, true)
 }
 
 // InsertChainWithoutSealVerification works exactly the same
@@ -1609,14 +1642,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 	bc.blockProcFeed.Send(true)
 	defer bc.blockProcFeed.Send(false)
 
-	// Pre-checks passed, start the full block imports
-	bc.wg.Add(1)
-	bc.chainmu.Lock()
-	n, err := bc.insertChain(types.Blocks([]*types.Block{block}), false)
-	bc.chainmu.Unlock()
-	bc.wg.Done()
-
-	return n, err
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
+	defer bc.chainmu.Unlock()
+	return bc.insertChain(types.Blocks([]*types.Block{block}), false)
 }
 
 // insertChain is the internal implementation of InsertChain, which assumes that
@@ -1628,10 +1658,11 @@ func (bc *BlockChain) InsertChainWithoutSealVerification(block *types.Block) (in
 // is imported, but then new canon-head is added before the actual sidechain
 // completes, then the historic state could be pruned again
 func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, error) {
-	// If the chain is terminating, don't even bother starting up
-	if atomic.LoadInt32(&bc.procInterrupt) == 1 {
+	// If the chain is terminating, don't even bother starting up.
+	if bc.insertStopped() {
 		return 0, nil
 	}
+
 	// Start a parallel signature recovery (signer will fluke on fork transition, minimal perf loss)
 	senderCacher.recoverFromBlocks(types.MakeSigner(bc.chainConfig, chain[0].Number()), chain)
 
@@ -1666,8 +1697,8 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		// First block (and state) is known
 		//   1. We did a roll-back, and should now do a re-import
 		//   2. The block is stored as a sidechain, and is lying about it's stateroot, and passes a stateroot
-		// 	    from the canonical chain, which has not been verified.
-		// Skip all known blocks that are behind us
+		//      from the canonical chain, which has not been verified.
+		// Skip all known blocks that are behind us.
 		var (
 			current  = bc.CurrentBlock()
 			localTd  = bc.GetTd(current.Hash(), current.NumberU64())
@@ -1791,9 +1822,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			lastCanon = block
 			continue
 		}
+
 		// Retrieve the parent block and it's state to execute on top
 		start := time.Now()
-
 		parent := it.previous()
 		if parent == nil {
 			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
@@ -1802,6 +1833,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		if err != nil {
 			return it.index, err
 		}
+
 		// Enable prefetching to pull in trie node paths while processing transactions
 		statedb.StartPrefetcher("chain")
 		activeState = statedb
@@ -1823,6 +1855,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 				}(time.Now(), followup, throwaway, &followupInterrupt)
 			}
 		}
+
 		// Process block using the parent state as reference point
 		substart := time.Now()
 		receipts, logs, usedGas, err := bc.processor.Process(block, statedb, bc.vmConfig)
@@ -1831,6 +1864,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 			atomic.StoreUint32(&followupInterrupt, 1)
 			return it.index, err
 		}
+
 		// Update the metrics touched during block processing
 		accountReadTimer.Update(statedb.AccountReads)                 // Account reads are complete, we can mark them
 		storageReadTimer.Update(statedb.StorageReads)                 // Storage reads are complete, we can mark them
@@ -1906,6 +1940,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, er
 		dirty, _ := bc.stateCache.TrieDB().Size()
 		stats.report(chain, it.index, dirty)
 	}
+
 	// Any blocks remaining here? The only ones we care about are the future ones
 	if block != nil && errors.Is(err, consensus.ErrFutureBlock) {
 		if err := bc.addFutureBlock(block); err != nil {
@@ -2215,7 +2250,10 @@ func (bc *BlockChain) reorg(oldBlock, newBlock *types.Block) error {
 	return nil
 }
 
-func (bc *BlockChain) update() {
+// futureBlocksLoop processes the 'future block' queue.
+func (bc *BlockChain) futureBlocksLoop() {
+	defer bc.wg.Done()
+
 	futureTimer := time.NewTicker(5 * time.Second)
 	defer futureTimer.Stop()
 	for {
@@ -2252,6 +2290,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 		}
 		rawdb.IndexTransactions(bc.db, from, ancients, bc.quit)
 	}
+
 	// indexBlocks reindexes or unindexes transactions depending on user configuration
 	indexBlocks := func(tail *uint64, head uint64, done chan struct{}) {
 		defer func() { done <- struct{}{} }()
@@ -2284,6 +2323,7 @@ func (bc *BlockChain) maintainTxIndex(ancients uint64) {
 			rawdb.UnindexTransactions(bc.db, *tail, head-bc.txLookupLimit+1, bc.quit)
 		}
 	}
+
 	// Any reindexing done, start listening to chain events and moving the index window
 	var (
 		done   chan struct{}                  // Non-nil if background unindexing or reindexing routine is active.
@@ -2351,12 +2391,10 @@ func (bc *BlockChain) InsertHeaderChain(chain []*types.Header, checkFreq int) (i
 		return i, err
 	}
 
-	// Make sure only one thread manipulates the chain at once
-	bc.chainmu.Lock()
+	if !bc.chainmu.TryLock() {
+		return 0, errChainStopped
+	}
 	defer bc.chainmu.Unlock()
-
-	bc.wg.Add(1)
-	defer bc.wg.Done()
 	_, err := bc.hc.InsertHeaderChain(chain, start)
 	return 0, err
 }
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index 8d94f17aa..4c3291dc3 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -163,7 +163,8 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		blockchain.chainmu.Lock()
+
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, block.Hash(), block.NumberU64(), new(big.Int).Add(block.Difficulty(), blockchain.GetTdByHash(block.ParentHash())))
 		rawdb.WriteBlock(blockchain.db, block)
 		statedb.Commit(false)
@@ -181,7 +182,7 @@ func testHeaderChainImport(chain []*types.Header, blockchain *BlockChain) error
 			return err
 		}
 		// Manually insert the header into the database, but don't reorganise (allows subsequent testing)
-		blockchain.chainmu.Lock()
+		blockchain.chainmu.MustLock()
 		rawdb.WriteTd(blockchain.db, header.Hash(), header.Number.Uint64(), new(big.Int).Add(header.Difficulty, blockchain.GetTdByHash(header.ParentHash)))
 		rawdb.WriteHeader(blockchain.db, header)
 		blockchain.chainmu.Unlock()
diff --git a/internal/syncx/mutex.go b/internal/syncx/mutex.go
new file mode 100644
index 000000000..96a21986c
--- /dev/null
+++ b/internal/syncx/mutex.go
@@ -0,0 +1,64 @@
+// Copyright 2021 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+// Package syncx contains exotic synchronization primitives.
+package syncx
+
+// ClosableMutex is a mutex that can also be closed.
+// Once closed, it can never be taken again.
+type ClosableMutex struct {
+	ch chan struct{}
+}
+
+func NewClosableMutex() *ClosableMutex {
+	ch := make(chan struct{}, 1)
+	ch <- struct{}{}
+	return &ClosableMutex{ch}
+}
+
+// TryLock attempts to lock cm.
+// If the mutex is closed, TryLock returns false.
+func (cm *ClosableMutex) TryLock() bool {
+	_, ok := <-cm.ch
+	return ok
+}
+
+// MustLock locks cm.
+// If the mutex is closed, MustLock panics.
+func (cm *ClosableMutex) MustLock() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("mutex closed")
+	}
+}
+
+// Unlock unlocks cm.
+func (cm *ClosableMutex) Unlock() {
+	select {
+	case cm.ch <- struct{}{}:
+	default:
+		panic("Unlock of already-unlocked ClosableMutex")
+	}
+}
+
+// Close locks the mutex, then closes it.
+func (cm *ClosableMutex) Close() {
+	_, ok := <-cm.ch
+	if !ok {
+		panic("Close of already-closed ClosableMutex")
+	}
+	close(cm.ch)
+}
