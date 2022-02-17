commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
commit f5abc9f188fb684e3601314b8ae454ac5abbf0e9
Author: obscuren <geffobscura@gmail.com>
Date:   Wed Jun 17 17:09:39 2015 +0200

    core, core/vm: state improvements and tx pool speed up
    
    Removed full tx validation during state transitions

diff --git a/core/block_processor.go b/core/block_processor.go
index 748750e32..c6df2d0f4 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -249,15 +249,13 @@ func (sm *BlockProcessor) processWithParent(block, parent *types.Block) (logs st
 	// Sync the current block's state to the database
 	state.Sync()
 
-	go func() {
-		// This puts transactions in a extra db for rpc
-		for i, tx := range block.Transactions() {
-			putTx(sm.extraDb, tx, block, uint64(i))
-		}
+	// This puts transactions in a extra db for rpc
+	for i, tx := range block.Transactions() {
+		putTx(sm.extraDb, tx, block, uint64(i))
+	}
 
-		// store the receipts
-		putReceipts(sm.extraDb, block.Hash(), receipts)
-	}()
+	// store the receipts
+	putReceipts(sm.extraDb, block.Hash(), receipts)
 
 	return state.Logs(), nil
 }
diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index e31f5c6b3..5ebe3576b 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -105,7 +105,9 @@ func (pool *TxPool) resetState() {
 		if addr, err := tx.From(); err == nil {
 			// Set the nonce. Transaction nonce can never be lower
 			// than the state nonce; validatePool took care of that.
-			pool.pendingState.SetNonce(addr, tx.Nonce())
+			if pool.pendingState.GetNonce(addr) < tx.Nonce() {
+				pool.pendingState.SetNonce(addr, tx.Nonce())
+			}
 		}
 	}
 
@@ -153,6 +155,11 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrNonExistentAccount
 	}
 
+	// Last but not least check for nonce errors
+	if pool.currentState().GetNonce(from) > tx.Nonce() {
+		return ErrNonce
+	}
+
 	// Check the transaction doesn't exceed the current
 	// block limit gas.
 	if pool.gasLimit().Cmp(tx.GasLimit) < 0 {
@@ -179,12 +186,6 @@ func (pool *TxPool) validateTx(tx *types.Transaction) error {
 		return ErrIntrinsicGas
 	}
 
-	// Last but not least check for nonce errors (intensive
-	// operation, saved for last)
-	if pool.currentState().GetNonce(from) > tx.Nonce() {
-		return ErrNonce
-	}
-
 	return nil
 }
 
@@ -394,10 +395,13 @@ func (pool *TxPool) removeTx(hash common.Hash) {
 
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
+	state := pool.currentState()
 	for hash, tx := range pool.pending {
-		if err := pool.validateTx(tx); err != nil {
+		from, _ := tx.From() // err already checked
+		// perform light nonce validation
+		if state.GetNonce(from) > tx.Nonce() {
 			if glog.V(logger.Core) {
-				glog.Infof("removed tx (%x) from pool: %v\n", hash[:4], err)
+				glog.Infof("removed tx (%x) from pool: low tx nonce\n", hash[:4])
 			}
 			delete(pool.pending, hash)
 		}
diff --git a/core/vm/context.go b/core/vm/context.go
index 56e8f925a..e33324b53 100644
--- a/core/vm/context.go
+++ b/core/vm/context.go
@@ -26,25 +26,16 @@ type Context struct {
 	Args []byte
 }
 
-var dests destinations
-
-func init() {
-	dests = make(destinations)
-}
-
 // Create a new context for the given data items.
 func NewContext(caller ContextRef, object ContextRef, value, gas, price *big.Int) *Context {
 	c := &Context{caller: caller, self: object, Args: nil}
 
-	/*
-		if parent, ok := caller.(*Context); ok {
-			// Reuse JUMPDEST analysis from parent context if available.
-			c.jumpdests = parent.jumpdests
-		} else {
-			c.jumpdests = make(destinations)
-		}
-	*/
-	c.jumpdests = dests
+	if parent, ok := caller.(*Context); ok {
+		// Reuse JUMPDEST analysis from parent context if available.
+		c.jumpdests = parent.jumpdests
+	} else {
+		c.jumpdests = make(destinations)
+	}
 
 	// Gas should be a pointer so it can safely be reduced through the run
 	// This pointer will be off the state transition
