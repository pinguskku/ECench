commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
commit 61ca780f3ba21ef1e62aab545160de12cbbf45bf
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Tue Jun 30 11:04:30 2015 +0200

    core: reduce CPU load by reducing calls to checkQueue
    
    * Reduced maxQueue count
    * Added proper deletion past maxQueue limit
    * Added cheap stats method to txpool
    
    queueCheck was called for **every** transaction instead of:
    1. add all txs
    2. check queue
    
    previously
    
    1. add txs[i]
    2. check queue
    3. if i < len(txs) goto 1.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bf28647c3..6a7012c65 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -29,7 +29,7 @@ var (
 )
 
 const (
-	maxQueued = 200 // max limit of queued txs per address
+	maxQueued = 64 // max limit of queued txs per address
 )
 
 type stateFn func() *state.StateDB
@@ -129,6 +129,17 @@ func (pool *TxPool) State() *state.ManagedState {
 	return pool.pendingState
 }
 
+func (pool *TxPool) Stats() (pending int, queued int) {
+	pool.mu.RLock()
+	defer pool.mu.RUnlock()
+
+	pending = len(pool.pending)
+	for _, txs := range pool.queue {
+		queued += len(txs)
+	}
+	return
+}
+
 // validateTx checks whether a transaction is valid according
 // to the consensus rules.
 func (pool *TxPool) validateTx(tx *types.Transaction) error {
@@ -214,9 +225,6 @@ func (self *TxPool) add(tx *types.Transaction) error {
 		glog.Infof("(t) %x => %s (%v) %x\n", from, toname, tx.Value, hash)
 	}
 
-	// check and validate the queueue
-	self.checkQueue()
-
 	return nil
 }
 
@@ -245,11 +253,17 @@ func (pool *TxPool) addTx(hash common.Hash, addr common.Address, tx *types.Trans
 }
 
 // Add queues a single transaction in the pool if it is valid.
-func (self *TxPool) Add(tx *types.Transaction) error {
+func (self *TxPool) Add(tx *types.Transaction) (err error) {
 	self.mu.Lock()
 	defer self.mu.Unlock()
 
-	return self.add(tx)
+	err = self.add(tx)
+	if err == nil {
+		// check and validate the queueue
+		self.checkQueue()
+	}
+
+	return
 }
 
 // AddTransactions attempts to queue all valid transactions in txs.
@@ -265,6 +279,9 @@ func (self *TxPool) AddTransactions(txs []*types.Transaction) {
 			glog.V(logger.Debug).Infof("tx %x\n", h[:4])
 		}
 	}
+
+	// check and validate the queueue
+	self.checkQueue()
 }
 
 // GetTransaction returns a transaction if it is contained in the pool
@@ -327,6 +344,23 @@ func (self *TxPool) RemoveTransactions(txs types.Transactions) {
 	}
 }
 
+func (pool *TxPool) removeTx(hash common.Hash) {
+	// delete from pending pool
+	delete(pool.pending, hash)
+	// delete from queue
+	for address, txs := range pool.queue {
+		if _, ok := txs[hash]; ok {
+			if len(txs) == 1 {
+				// if only one tx, remove entire address entry.
+				delete(pool.queue, address)
+			} else {
+				delete(txs, hash)
+			}
+			break
+		}
+	}
+}
+
 // checkQueue moves transactions that have become processable to main pool.
 func (pool *TxPool) checkQueue() {
 	state := pool.pendingState
@@ -354,13 +388,19 @@ func (pool *TxPool) checkQueue() {
 		for i, e := range addq {
 			// start deleting the transactions from the queue if they exceed the limit
 			if i > maxQueued {
-				if glog.V(logger.Debug) {
-					glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
-				}
 				delete(pool.queue[address], e.hash)
 				continue
 			}
+
 			if e.Nonce() > guessedNonce {
+				if len(addq)-i > maxQueued {
+					if glog.V(logger.Debug) {
+						glog.Infof("Queued tx limit exceeded for %s. Tx %s removed\n", common.PP(address[:]), common.PP(e.hash[:]))
+					}
+					for j := i + maxQueued; j < len(addq); j++ {
+						delete(txs, addq[j].hash)
+					}
+				}
 				break
 			}
 			delete(txs, e.hash)
@@ -373,23 +413,6 @@ func (pool *TxPool) checkQueue() {
 	}
 }
 
-func (pool *TxPool) removeTx(hash common.Hash) {
-	// delete from pending pool
-	delete(pool.pending, hash)
-	// delete from queue
-	for address, txs := range pool.queue {
-		if _, ok := txs[hash]; ok {
-			if len(txs) == 1 {
-				// if only one tx, remove entire address entry.
-				delete(pool.queue, address)
-			} else {
-				delete(txs, hash)
-			}
-			break
-		}
-	}
-}
-
 // validatePool removes invalid and processed transactions from the main pool.
 func (pool *TxPool) validatePool() {
 	state := pool.currentState()
diff --git a/core/transaction_pool_test.go b/core/transaction_pool_test.go
index ff8b9c730..5744ef059 100644
--- a/core/transaction_pool_test.go
+++ b/core/transaction_pool_test.go
@@ -181,6 +181,8 @@ func TestTransactionDoubleNonce(t *testing.T) {
 	if err := pool.add(tx2); err != nil {
 		t.Error("didn't expect error", err)
 	}
+
+	pool.checkQueue()
 	if len(pool.pending) != 2 {
 		t.Error("expected 2 pending txs. Got", len(pool.pending))
 	}
diff --git a/rpc/api/txpool.go b/rpc/api/txpool.go
index 25ad6e9b2..04faf463c 100644
--- a/rpc/api/txpool.go
+++ b/rpc/api/txpool.go
@@ -68,8 +68,9 @@ func (self *txPoolApi) ApiVersion() string {
 }
 
 func (self *txPoolApi) Status(req *shared.Request) (interface{}, error) {
+	pending, queue := self.ethereum.TxPool().Stats()
 	return map[string]int{
-		"pending": self.ethereum.TxPool().GetTransactions().Len(),
-		"queued":  self.ethereum.TxPool().GetQueuedTransactions().Len(),
+		"pending": pending,
+		"queued":  queue,
 	}, nil
 }
