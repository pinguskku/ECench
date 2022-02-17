commit e1ed8c33bd99a87d2c3339fe28a602b1af8b85fc
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sat Apr 4 16:35:23 2015 +0200

    Improved chain manager, improved block processor, fixed tests
    
    * ChainManager allows cached future blocks for later processing
    * BlockProcessor allows a 4 second window on future blocks
    * Fixed tests

diff --git a/core/block_processor.go b/core/block_processor.go
index c9d0c2228..6b18d4cf9 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -260,7 +260,7 @@ func (sm *BlockProcessor) ValidateHeader(block, parent *types.Header) error {
 	}
 
 	// Allow future blocks up to 10 seconds
-	if int64(block.Time)+10 > time.Now().Unix() {
+	if int64(block.Time) > time.Now().Unix()+4 {
 		return BlockFutureErr
 	}
 
diff --git a/core/block_processor_test.go b/core/block_processor_test.go
index 64add7e8b..02524a4c1 100644
--- a/core/block_processor_test.go
+++ b/core/block_processor_test.go
@@ -22,10 +22,11 @@ func TestNumber(t *testing.T) {
 	bp, chain := proc()
 	block1 := chain.NewBlock(common.Address{})
 	block1.Header().Number = big.NewInt(3)
+	block1.Header().Time--
 
 	err := bp.ValidateHeader(block1.Header(), chain.Genesis().Header())
 	if err != BlockNumberErr {
-		t.Errorf("expected block number error")
+		t.Errorf("expected block number error %v", err)
 	}
 
 	block1 = chain.NewBlock(common.Address{})
diff --git a/core/chain_makers.go b/core/chain_makers.go
index 52cb367c5..6597cc315 100644
--- a/core/chain_makers.go
+++ b/core/chain_makers.go
@@ -109,6 +109,7 @@ func makeChain(bman *BlockProcessor, parent *types.Block, max int, db common.Dat
 // Effectively a fork factory
 func newChainManager(block *types.Block, eventMux *event.TypeMux, db common.Database) *ChainManager {
 	bc := &ChainManager{blockDb: db, stateDb: db, genesisBlock: GenesisBlock(db), eventMux: eventMux}
+	bc.futureBlocks = NewBlockCache(1000)
 	if block == nil {
 		bc.Reset()
 	} else {
diff --git a/core/chain_manager.go b/core/chain_manager.go
index c1a07b0cf..7b4034b63 100644
--- a/core/chain_manager.go
+++ b/core/chain_manager.go
@@ -6,6 +6,7 @@ import (
 	"io"
 	"math/big"
 	"sync"
+	"time"
 
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -95,7 +96,8 @@ type ChainManager struct {
 	transState *state.StateDB
 	txState    *state.ManagedState
 
-	cache *BlockCache
+	cache        *BlockCache
+	futureBlocks *BlockCache
 
 	quit chan struct{}
 }
@@ -107,6 +109,7 @@ func NewChainManager(blockDb, stateDb common.Database, mux *event.TypeMux) *Chai
 	// Take ownership of this particular state
 	bc.txState = state.ManageState(bc.State().Copy())
 
+	bc.futureBlocks = NewBlockCache(254)
 	bc.makeCache()
 
 	go bc.update()
@@ -433,6 +436,19 @@ type queueEvent struct {
 	splitCount     int
 }
 
+func (self *ChainManager) procFutureBlocks() {
+	self.futureBlocks.mu.Lock()
+
+	blocks := make([]*types.Block, len(self.futureBlocks.blocks))
+	for i, hash := range self.futureBlocks.hashes {
+		blocks[i] = self.futureBlocks.Get(hash)
+	}
+	self.futureBlocks.mu.Unlock()
+
+	types.BlockBy(types.Number).Sort(blocks)
+	self.InsertChain(blocks)
+}
+
 func (self *ChainManager) InsertChain(chain types.Blocks) error {
 	//self.tsmu.Lock()
 	//defer self.tsmu.Unlock()
@@ -452,12 +468,27 @@ func (self *ChainManager) InsertChain(chain types.Blocks) error {
 				continue
 			}
 
-			if err == BlockEqualTSErr {
-				//queue[i] = ChainSideEvent{block, logs}
-				// XXX silently discard it?
+			block.Td = new(big.Int)
+			// Do not penelise on future block. We'll need a block queue eventually that will queue
+			// future block for future use
+			if err == BlockFutureErr {
+				self.futureBlocks.Push(block)
+				continue
+			}
+
+			if IsParentErr(err) && self.futureBlocks.Has(block.ParentHash()) {
+				self.futureBlocks.Push(block)
 				continue
 			}
 
+			/*
+				if err == BlockEqualTSErr {
+					//queue[i] = ChainSideEvent{block, logs}
+					// XXX silently discard it?
+					continue
+				}
+			*/
+
 			h := block.Header()
 			chainlogger.Errorf("INVALID block #%v (%x)\n", h.Number, h.Hash().Bytes()[:4])
 			chainlogger.Errorln(err)
@@ -513,6 +544,8 @@ func (self *ChainManager) InsertChain(chain types.Blocks) error {
 		}
 		self.mu.Unlock()
 
+		self.futureBlocks.Delete(block.Hash())
+
 	}
 
 	if len(chain) > 0 && glog.V(logger.Info) {
@@ -527,7 +560,7 @@ func (self *ChainManager) InsertChain(chain types.Blocks) error {
 
 func (self *ChainManager) update() {
 	events := self.eventMux.Subscribe(queueEvent{})
-
+	futureTimer := time.NewTicker(5 * time.Second)
 out:
 	for {
 		select {
@@ -553,6 +586,8 @@ out:
 					self.eventMux.Post(event)
 				}
 			}
+		case <-futureTimer.C:
+			self.procFutureBlocks()
 		case <-self.quit:
 			break out
 		}
