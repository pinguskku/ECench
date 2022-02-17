commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
commit 4f457859a2e76bec4a76a7019d5bb480850f8918
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Mar 13 12:31:35 2019 +0200

    core: use headers only where blocks are unnecessary

diff --git a/core/block_validator.go b/core/block_validator.go
index 3b9496fec..b36ca56d7 100644
--- a/core/block_validator.go
+++ b/core/block_validator.go
@@ -77,7 +77,7 @@ func (v *BlockValidator) ValidateBody(block *types.Block) error {
 // transition, such as amount of used gas, the receipt roots and the state root
 // itself. ValidateState returns a database batch if the validation was a success
 // otherwise nil and an error is returned.
-func (v *BlockValidator) ValidateState(block, parent *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
+func (v *BlockValidator) ValidateState(block *types.Block, statedb *state.StateDB, receipts types.Receipts, usedGas uint64) error {
 	header := block.Header()
 	if block.GasUsed() != usedGas {
 		return fmt.Errorf("invalid gas used (remote: %d local: %d)", block.GasUsed(), usedGas)
diff --git a/core/blockchain.go b/core/blockchain.go
index 71e806e6e..d59ee99cd 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -1221,9 +1221,9 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 
 		parent := it.previous()
 		if parent == nil {
-			parent = bc.GetBlock(block.ParentHash(), block.NumberU64()-1)
+			parent = bc.GetHeader(block.ParentHash(), block.NumberU64()-1)
 		}
-		state, err := state.New(parent.Root(), bc.stateCache)
+		state, err := state.New(parent.Root, bc.stateCache)
 		if err != nil {
 			return it.index, events, coalescedLogs, err
 		}
@@ -1236,7 +1236,7 @@ func (bc *BlockChain) insertChain(chain types.Blocks, verifySeals bool) (int, []
 			return it.index, events, coalescedLogs, err
 		}
 		// Validate the state using the default validator
-		if err := bc.Validator().ValidateState(block, parent, state, receipts, usedGas); err != nil {
+		if err := bc.Validator().ValidateState(block, state, receipts, usedGas); err != nil {
 			bc.reportBlock(block, receipts, err)
 			return it.index, events, coalescedLogs, err
 		}
@@ -1368,7 +1368,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 	// blocks to regenerate the required state
 	localTd := bc.GetTd(current.Hash(), current.NumberU64())
 	if localTd.Cmp(externTd) > 0 {
-		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().NumberU64(), "sidetd", externTd, "localtd", localTd)
+		log.Info("Sidechain written to disk", "start", it.first().NumberU64(), "end", it.previous().Number, "sidetd", externTd, "localtd", localTd)
 		return it.index, nil, nil, err
 	}
 	// Gather all the sidechain hashes (full blocks may be memory heavy)
@@ -1376,7 +1376,7 @@ func (bc *BlockChain) insertSidechain(block *types.Block, it *insertIterator) (i
 		hashes  []common.Hash
 		numbers []uint64
 	)
-	parent := bc.GetHeader(it.previous().Hash(), it.previous().NumberU64())
+	parent := it.previous()
 	for parent != nil && !bc.HasState(parent.Root) {
 		hashes = append(hashes, parent.Hash())
 		numbers = append(numbers, parent.Number.Uint64())
diff --git a/core/blockchain_insert.go b/core/blockchain_insert.go
index f07e24d75..e2a385164 100644
--- a/core/blockchain_insert.go
+++ b/core/blockchain_insert.go
@@ -111,12 +111,12 @@ func (it *insertIterator) next() (*types.Block, error) {
 	return it.chain[it.index], it.validator.ValidateBody(it.chain[it.index])
 }
 
-// previous returns the previous block was being processed, or nil
-func (it *insertIterator) previous() *types.Block {
+// previous returns the previous header that was being processed, or nil.
+func (it *insertIterator) previous() *types.Header {
 	if it.index < 1 {
 		return nil
 	}
-	return it.chain[it.index-1]
+	return it.chain[it.index-1].Header()
 }
 
 // first returns the first block in the it.
diff --git a/core/blockchain_test.go b/core/blockchain_test.go
index c9e999cc9..d1681ce3b 100644
--- a/core/blockchain_test.go
+++ b/core/blockchain_test.go
@@ -149,7 +149,7 @@ func testBlockChainImport(chain types.Blocks, blockchain *BlockChain) error {
 			blockchain.reportBlock(block, receipts, err)
 			return err
 		}
-		err = blockchain.validator.ValidateState(block, blockchain.GetBlockByHash(block.ParentHash()), statedb, receipts, usedGas)
+		err = blockchain.validator.ValidateState(block, statedb, receipts, usedGas)
 		if err != nil {
 			blockchain.reportBlock(block, receipts, err)
 			return err
diff --git a/core/types.go b/core/types.go
index d0bbaf0aa..5c963e665 100644
--- a/core/types.go
+++ b/core/types.go
@@ -32,7 +32,7 @@ type Validator interface {
 
 	// ValidateState validates the given statedb and optionally the receipts and
 	// gas used.
-	ValidateState(block, parent *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
+	ValidateState(block *types.Block, state *state.StateDB, receipts types.Receipts, usedGas uint64) error
 }
 
 // Processor is an interface for processing blocks using a given initial state.
