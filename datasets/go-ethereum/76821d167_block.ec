commit 76821d167acd7da15e13b23beeceb6779138ffe5
Author: Felix Lange <fjl@twurst.com>
Date:   Sat Jun 27 03:08:50 2015 +0200

    core, eth, rpc: avoid unnecessary block header copying

diff --git a/core/block_processor.go b/core/block_processor.go
index 4b27f8797..22d4c7c27 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -186,7 +186,7 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	txs := block.Transactions()
 
 	// Block validation
-	if err = ValidateHeader(sm.Pow, header, parent.Header(), false); err != nil {
+	if err = ValidateHeader(sm.Pow, header, parent, false); err != nil {
 		return
 	}
 
@@ -285,19 +285,18 @@ func AccumulateRewards(statedb *state.StateDB, header *types.Header, uncles []*t
 }
 
 func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *types.Block) error {
-	ancestors := set.New()
 	uncles := set.New()
-	ancestorHeaders := make(map[common.Hash]*types.Header)
+	ancestors := make(map[common.Hash]*types.Block)
 	for _, ancestor := range sm.bc.GetBlocksFromHash(block.ParentHash(), 7) {
-		ancestorHeaders[ancestor.Hash()] = ancestor.Header()
-		ancestors.Add(ancestor.Hash())
+		ancestors[ancestor.Hash()] = ancestor
 		// Include ancestors uncles in the uncle set. Uncles must be unique.
 		for _, uncle := range ancestor.Uncles() {
 			uncles.Add(uncle.Hash())
 		}
 	}
-
+	ancestors[block.Hash()] = block
 	uncles.Add(block.Hash())
+
 	for i, uncle := range block.Uncles() {
 		hash := uncle.Hash()
 		if uncles.Has(hash) {
@@ -306,22 +305,20 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 		}
 		uncles.Add(hash)
 
-		if ancestors.Has(hash) {
+		if ancestors[hash] != nil {
 			branch := fmt.Sprintf("  O - %x\n  |\n", block.Hash())
-			ancestors.Each(func(item interface{}) bool {
-				branch += fmt.Sprintf("  O - %x\n  |\n", hash)
-				return true
-			})
+			for h := range ancestors {
+				branch += fmt.Sprintf("  O - %x\n  |\n", h)
+			}
 			glog.Infoln(branch)
-
 			return UncleError("uncle[%d](%x) is ancestor", i, hash[:4])
 		}
 
-		if !ancestors.Has(uncle.ParentHash) || uncle.ParentHash == parent.Hash() {
+		if ancestors[uncle.ParentHash] == nil || uncle.ParentHash == parent.Hash() {
 			return UncleError("uncle[%d](%x)'s parent is not ancestor (%x)", i, hash[:4], uncle.ParentHash[0:4])
 		}
 
-		if err := ValidateHeader(sm.Pow, uncle, ancestorHeaders[uncle.ParentHash], true); err != nil {
+		if err := ValidateHeader(sm.Pow, uncle, ancestors[uncle.ParentHash], true); err != nil {
 			return ValidationError(fmt.Sprintf("uncle[%d](%x) header invalid: %v", i, hash[:4], err))
 		}
 	}
@@ -360,19 +357,22 @@ func (sm *BlockProcessor) GetLogs(block *types.Block) (logs state.Logs, err erro
 
 // See YP section 4.3.4. "Block Header Validity"
 // Validates a block. Returns an error if the block is invalid.
-func ValidateHeader(pow pow.PoW, block, parent *types.Header, checkPow bool) error {
+func ValidateHeader(pow pow.PoW, block *types.Header, parent *types.Block, checkPow bool) error {
 	if big.NewInt(int64(len(block.Extra))).Cmp(params.MaximumExtraDataSize) == 1 {
 		return fmt.Errorf("Block extra data too long (%d)", len(block.Extra))
 	}
 
-	expd := CalcDifficulty(int64(block.Time), int64(parent.Time), parent.Difficulty)
+	expd := CalcDifficulty(int64(block.Time), int64(parent.Time()), parent.Difficulty())
 	if expd.Cmp(block.Difficulty) != 0 {
 		return fmt.Errorf("Difficulty check failed for block %v, %v", block.Difficulty, expd)
 	}
 
-	a := new(big.Int).Sub(block.GasLimit, parent.GasLimit)
+	var a, b *big.Int
+	a = parent.GasLimit()
+	a = a.Sub(a, block.GasLimit)
 	a.Abs(a)
-	b := new(big.Int).Div(parent.GasLimit, params.GasLimitBoundDivisor)
+	b = parent.GasLimit()
+	b = b.Div(b, params.GasLimitBoundDivisor)
 	if !(a.Cmp(b) < 0) || (block.GasLimit.Cmp(params.MinGasLimit) == -1) {
 		return fmt.Errorf("GasLimit check failed for block %v (%v > %v)", block.GasLimit, a, b)
 	}
@@ -381,11 +381,13 @@ func ValidateHeader(pow pow.PoW, block, parent *types.Header, checkPow bool) err
 		return BlockFutureErr
 	}
 
-	if new(big.Int).Sub(block.Number, parent.Number).Cmp(big.NewInt(1)) != 0 {
+	num := parent.Number()
+	num.Sub(block.Number, num)
+	if num.Cmp(big.NewInt(1)) != 0 {
 		return BlockNumberErr
 	}
 
-	if block.Time <= parent.Time {
+	if block.Time <= uint64(parent.Time()) {
 		return BlockEqualTSErr //ValidationError("Block timestamp equal or less than previous block (%v - %v)", block.Time, parent.Time)
 	}
 
diff --git a/core/block_processor_test.go b/core/block_processor_test.go
index 5931a5f5e..dc328a3ea 100644
--- a/core/block_processor_test.go
+++ b/core/block_processor_test.go
@@ -32,13 +32,13 @@ func TestNumber(t *testing.T) {
 	statedb := state.New(chain.Genesis().Root(), chain.stateDb)
 	header := makeHeader(chain.Genesis(), statedb)
 	header.Number = big.NewInt(3)
-	err := ValidateHeader(pow, header, chain.Genesis().Header(), false)
+	err := ValidateHeader(pow, header, chain.Genesis(), false)
 	if err != BlockNumberErr {
 		t.Errorf("expected block number error, got %q", err)
 	}
 
 	header = makeHeader(chain.Genesis(), statedb)
-	err = ValidateHeader(pow, header, chain.Genesis().Header(), false)
+	err = ValidateHeader(pow, header, chain.Genesis(), false)
 	if err == BlockNumberErr {
 		t.Errorf("didn't expect block number error")
 	}
diff --git a/core/chain_manager.go b/core/chain_manager.go
index 8a8078381..070b6b1d0 100644
--- a/core/chain_manager.go
+++ b/core/chain_manager.go
@@ -164,7 +164,7 @@ func (bc *ChainManager) SetHead(head *types.Block) {
 	bc.mu.Lock()
 	defer bc.mu.Unlock()
 
-	for block := bc.currentBlock; block != nil && block.Hash() != head.Hash(); block = bc.GetBlock(block.Header().ParentHash) {
+	for block := bc.currentBlock; block != nil && block.Hash() != head.Hash(); block = bc.GetBlock(block.ParentHash()) {
 		bc.removeBlock(block)
 	}
 
@@ -269,7 +269,7 @@ func (bc *ChainManager) Reset() {
 	bc.mu.Lock()
 	defer bc.mu.Unlock()
 
-	for block := bc.currentBlock; block != nil; block = bc.GetBlock(block.Header().ParentHash) {
+	for block := bc.currentBlock; block != nil; block = bc.GetBlock(block.ParentHash()) {
 		bc.removeBlock(block)
 	}
 
@@ -294,7 +294,7 @@ func (bc *ChainManager) ResetWithGenesisBlock(gb *types.Block) {
 	bc.mu.Lock()
 	defer bc.mu.Unlock()
 
-	for block := bc.currentBlock; block != nil; block = bc.GetBlock(block.Header().ParentHash) {
+	for block := bc.currentBlock; block != nil; block = bc.GetBlock(block.ParentHash()) {
 		bc.removeBlock(block)
 	}
 
diff --git a/eth/gasprice.go b/eth/gasprice.go
index cd5293691..44202d709 100644
--- a/eth/gasprice.go
+++ b/eth/gasprice.go
@@ -133,20 +133,20 @@ func (self *GasPriceOracle) lowestPrice(block *types.Block) *big.Int {
 		gasUsed = recepits[len(recepits)-1].CumulativeGasUsed
 	}
 
-	if new(big.Int).Mul(gasUsed, big.NewInt(100)).Cmp(new(big.Int).Mul(block.Header().GasLimit,
+	if new(big.Int).Mul(gasUsed, big.NewInt(100)).Cmp(new(big.Int).Mul(block.GasLimit(),
 		big.NewInt(int64(self.eth.GpoFullBlockRatio)))) < 0 {
 		// block is not full, could have posted a tx with MinGasPrice
 		return self.eth.GpoMinGasPrice
 	}
 
-	if len(block.Transactions()) < 1 {
+	txs := block.Transactions()
+	if len(txs) == 0 {
 		return self.eth.GpoMinGasPrice
 	}
-
 	// block is full, find smallest gasPrice
-	minPrice := block.Transactions()[0].GasPrice()
-	for i := 1; i < len(block.Transactions()); i++ {
-		price := block.Transactions()[i].GasPrice()
+	minPrice := txs[0].GasPrice()
+	for i := 1; i < len(txs); i++ {
+		price := txs[i].GasPrice()
 		if price.Cmp(minPrice) < 0 {
 			minPrice = price
 		}
diff --git a/eth/handler.go b/eth/handler.go
index ad88e9c59..278a2bec2 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -93,7 +93,7 @@ func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpo
 	manager.downloader = downloader.New(manager.eventMux, manager.chainman.HasBlock, manager.chainman.GetBlock, manager.chainman.InsertChain, manager.removePeer)
 
 	validator := func(block *types.Block, parent *types.Block) error {
-		return core.ValidateHeader(pow, block.Header(), parent.Header(), true)
+		return core.ValidateHeader(pow, block.Header(), parent, true)
 	}
 	heighter := func() uint64 {
 		return manager.chainman.CurrentBlock().NumberU64()
diff --git a/rpc/api/parsing.go b/rpc/api/parsing.go
index 85a9165e5..632462c31 100644
--- a/rpc/api/parsing.go
+++ b/rpc/api/parsing.go
@@ -270,29 +270,31 @@ func NewBlockRes(block *types.Block, fullTx bool) *BlockRes {
 	res.BlockHash = newHexData(block.Hash())
 	res.ParentHash = newHexData(block.ParentHash())
 	res.Nonce = newHexData(block.Nonce())
-	res.Sha3Uncles = newHexData(block.Header().UncleHash)
+	res.Sha3Uncles = newHexData(block.UncleHash())
 	res.LogsBloom = newHexData(block.Bloom())
-	res.TransactionRoot = newHexData(block.Header().TxHash)
+	res.TransactionRoot = newHexData(block.TxHash())
 	res.StateRoot = newHexData(block.Root())
-	res.Miner = newHexData(block.Header().Coinbase)
+	res.Miner = newHexData(block.Coinbase())
 	res.Difficulty = newHexNum(block.Difficulty())
 	res.TotalDifficulty = newHexNum(block.Td)
 	res.Size = newHexNum(block.Size().Int64())
-	res.ExtraData = newHexData(block.Header().Extra)
+	res.ExtraData = newHexData(block.Extra())
 	res.GasLimit = newHexNum(block.GasLimit())
 	res.GasUsed = newHexNum(block.GasUsed())
 	res.UnixTimestamp = newHexNum(block.Time())
 
-	res.Transactions = make([]*TransactionRes, len(block.Transactions()))
-	for i, tx := range block.Transactions() {
+	txs := block.Transactions()
+	res.Transactions = make([]*TransactionRes, len(txs))
+	for i, tx := range txs {
 		res.Transactions[i] = NewTransactionRes(tx)
 		res.Transactions[i].BlockHash = res.BlockHash
 		res.Transactions[i].BlockNumber = res.BlockNumber
 		res.Transactions[i].TxIndex = newHexNum(i)
 	}
 
-	res.Uncles = make([]*UncleRes, len(block.Uncles()))
-	for i, uncle := range block.Uncles() {
+	uncles := block.Uncles()
+	res.Uncles = make([]*UncleRes, len(uncles))
+	for i, uncle := range uncles {
 		res.Uncles[i] = NewUncleRes(uncle)
 	}
 
