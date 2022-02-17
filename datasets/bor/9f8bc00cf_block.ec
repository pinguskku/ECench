commit 9f8bc00cf56bdf2cabf060303ed69f277a03357a
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Nov 30 10:48:48 2016 +0100

    eth, miner: removed unnecessary state.Copy()
    
    * miner: removed unnecessary state.Copy()
    
    * eth: made use of new miner method without state copying
    
    * miner: More documentation about new method

diff --git a/eth/api_backend.go b/eth/api_backend.go
index 0925132ef..7858dee2e 100644
--- a/eth/api_backend.go
+++ b/eth/api_backend.go
@@ -56,7 +56,7 @@ func (b *EthApiBackend) SetHead(number uint64) {
 func (b *EthApiBackend) HeaderByNumber(ctx context.Context, blockNr rpc.BlockNumber) (*types.Header, error) {
 	// Pending block is only known by the miner
 	if blockNr == rpc.PendingBlockNumber {
-		block, _ := b.eth.miner.Pending()
+		block := b.eth.miner.PendingBlock()
 		return block.Header(), nil
 	}
 	// Otherwise resolve and return the block
@@ -69,7 +69,7 @@ func (b *EthApiBackend) HeaderByNumber(ctx context.Context, blockNr rpc.BlockNum
 func (b *EthApiBackend) BlockByNumber(ctx context.Context, blockNr rpc.BlockNumber) (*types.Block, error) {
 	// Pending block is only known by the miner
 	if blockNr == rpc.PendingBlockNumber {
-		block, _ := b.eth.miner.Pending()
+		block := b.eth.miner.PendingBlock()
 		return block, nil
 	}
 	// Otherwise resolve and return the block
diff --git a/miner/miner.go b/miner/miner.go
index c85a1cd8e..87568ac18 100644
--- a/miner/miner.go
+++ b/miner/miner.go
@@ -187,6 +187,15 @@ func (self *Miner) Pending() (*types.Block, *state.StateDB) {
 	return self.worker.pending()
 }
 
+// PendingBlock returns the currently pending block.
+// 
+// Note, to access both the pending block and the pending state 
+// simultaneously, please use Pending(), as the pending state can 
+// change between multiple method calls
+func (self *Miner) PendingBlock() *types.Block {
+	return self.worker.pendingBlock()
+}
+
 func (self *Miner) SetEtherbase(addr common.Address) {
 	self.coinbase = addr
 	self.worker.setEtherbase(addr)
diff --git a/miner/worker.go b/miner/worker.go
index ca00c7229..edbd502c1 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -176,6 +176,21 @@ func (self *worker) pending() (*types.Block, *state.StateDB) {
 	return self.current.Block, self.current.state.Copy()
 }
 
+func (self *worker) pendingBlock() *types.Block {
+	self.currentMu.Lock()
+	defer self.currentMu.Unlock()
+
+	if atomic.LoadInt32(&self.mining) == 0 {
+		return types.NewBlock(
+			self.current.header,
+			self.current.txs,
+			nil,
+			self.current.receipts,
+		)
+	}
+	return self.current.Block
+}
+
 func (self *worker) start() {
 	self.mu.Lock()
 	defer self.mu.Unlock()
