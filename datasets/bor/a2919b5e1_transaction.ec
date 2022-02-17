commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
commit a2919b5e17197afcb689b8f4144f255a5872f85d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Sun May 10 23:12:18 2015 +0200

    core, eth, miner: improved tx removal & fatal error on db sync err
    
    * core: Added GasPriceChange event
    * eth: When one of the DB flush methods error a fatal error log message
      is given. Hopefully this will prevent corrupted databases from
      occuring.
    * miner: remove transactions with low gas price. Closes #906, #903

diff --git a/common/size.go b/common/size.go
index 0d9dbf558..4ea7f7b11 100644
--- a/common/size.go
+++ b/common/size.go
@@ -44,12 +44,6 @@ func CurrencyToString(num *big.Int) string {
 	)
 
 	switch {
-	case num.Cmp(Douglas) >= 0:
-		fin = new(big.Int).Div(num, Douglas)
-		denom = "Douglas"
-	case num.Cmp(Einstein) >= 0:
-		fin = new(big.Int).Div(num, Einstein)
-		denom = "Einstein"
 	case num.Cmp(Ether) >= 0:
 		fin = new(big.Int).Div(num, Ether)
 		denom = "Ether"
diff --git a/common/size_test.go b/common/size_test.go
index 1cbeff0a8..cfe7efe31 100644
--- a/common/size_test.go
+++ b/common/size_test.go
@@ -25,8 +25,6 @@ func (s *SizeSuite) TestStorageSizeString(c *checker.C) {
 }
 
 func (s *CommonSuite) TestCommon(c *checker.C) {
-	douglas := CurrencyToString(BigPow(10, 43))
-	einstein := CurrencyToString(BigPow(10, 22))
 	ether := CurrencyToString(BigPow(10, 19))
 	finney := CurrencyToString(BigPow(10, 16))
 	szabo := CurrencyToString(BigPow(10, 13))
@@ -35,8 +33,6 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	ada := CurrencyToString(BigPow(10, 4))
 	wei := CurrencyToString(big.NewInt(10))
 
-	c.Assert(douglas, checker.Equals, "10 Douglas")
-	c.Assert(einstein, checker.Equals, "10 Einstein")
 	c.Assert(ether, checker.Equals, "10 Ether")
 	c.Assert(finney, checker.Equals, "10 Finney")
 	c.Assert(szabo, checker.Equals, "10 Szabo")
@@ -45,13 +41,3 @@ func (s *CommonSuite) TestCommon(c *checker.C) {
 	c.Assert(ada, checker.Equals, "10 Ada")
 	c.Assert(wei, checker.Equals, "10 Wei")
 }
-
-func (s *CommonSuite) TestLarge(c *checker.C) {
-	douglaslarge := CurrencyToString(BigPow(100000000, 43))
-	adalarge := CurrencyToString(BigPow(100000000, 4))
-	weilarge := CurrencyToString(big.NewInt(100000000))
-
-	c.Assert(douglaslarge, checker.Equals, "10000E298 Douglas")
-	c.Assert(adalarge, checker.Equals, "10000E7 Einstein")
-	c.Assert(weilarge, checker.Equals, "100 Babbage")
-}
diff --git a/core/events.go b/core/events.go
index 3da668af5..1ea35c2f4 100644
--- a/core/events.go
+++ b/core/events.go
@@ -1,8 +1,10 @@
 package core
 
 import (
-	"github.com/ethereum/go-ethereum/core/types"
+	"math/big"
+
 	"github.com/ethereum/go-ethereum/core/state"
+	"github.com/ethereum/go-ethereum/core/types"
 )
 
 // TxPreEvent is posted when a transaction enters the transaction pool.
@@ -44,6 +46,8 @@ type ChainUncleEvent struct {
 
 type ChainHeadEvent struct{ Block *types.Block }
 
+type GasPriceChanged struct{ Price *big.Int }
+
 // Mining operation events
 type StartMining struct{}
 type TopMining struct{}
diff --git a/core/manager.go b/core/manager.go
index 9b5407a9e..433ada7ee 100644
--- a/core/manager.go
+++ b/core/manager.go
@@ -1,12 +1,14 @@
 package core
 
 import (
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/p2p"
 )
 
 type Backend interface {
+	AccountManager() *accounts.Manager
 	BlockProcessor() *BlockProcessor
 	ChainManager() *ChainManager
 	TxPool() *TxPool
diff --git a/eth/backend.go b/eth/backend.go
index 8f0789467..cdbe35b26 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -451,6 +451,8 @@ func (s *Ethereum) Start() error {
 	return nil
 }
 
+// sync databases every minute. If flushing fails we exit immediatly. The system
+// may not continue under any circumstances.
 func (s *Ethereum) syncDatabases() {
 	ticker := time.NewTicker(1 * time.Minute)
 done:
@@ -459,13 +461,13 @@ done:
 		case <-ticker.C:
 			// don't change the order of database flushes
 			if err := s.extraDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush extraDb: %v\n", err)
+				glog.Fatalf("fatal error: flush extraDb: %v\n", err)
 			}
 			if err := s.stateDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush stateDb: %v\n", err)
+				glog.Fatalf("fatal error: flush stateDb: %v\n", err)
 			}
 			if err := s.blockDb.Flush(); err != nil {
-				glog.V(logger.Error).Infof("error: flush blockDb: %v\n", err)
+				glog.Fatalf("fatal error: flush blockDb: %v\n", err)
 			}
 		case <-s.shutdownChan:
 			break done
diff --git a/miner/worker.go b/miner/worker.go
index 22493c235..4ba566eec 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -7,6 +7,7 @@ import (
 	"sync"
 	"sync/atomic"
 
+	"github.com/ethereum/go-ethereum/accounts"
 	"github.com/ethereum/go-ethereum/common"
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/state"
@@ -253,7 +254,12 @@ func (self *worker) makeCurrent() {
 func (w *worker) setGasPrice(p *big.Int) {
 	w.mu.Lock()
 	defer w.mu.Unlock()
-	w.gasPrice = p
+
+	// calculate the minimal gas price the miner accepts when sorting out transactions.
+	const pct = int64(90)
+	w.gasPrice = gasprice(p, pct)
+
+	w.mux.Post(core.GasPriceChanged{w.gasPrice})
 }
 
 func (self *worker) commitNewWork() {
@@ -269,27 +275,40 @@ func (self *worker) commitNewWork() {
 	transactions := self.eth.TxPool().GetTransactions()
 	sort.Sort(types.TxByNonce{transactions})
 
+	accounts, _ := self.eth.AccountManager().Accounts()
 	// Keep track of transactions which return errors so they can be removed
 	var (
 		remove             = set.New()
 		tcount             = 0
 		ignoredTransactors = set.New()
+		lowGasTransactors  = set.New()
+		ownedAccounts      = accountAddressesSet(accounts)
+		lowGasTxs          types.Transactions
 	)
 
-	const pct = int64(90)
-	// calculate the minimal gas price the miner accepts when sorting out transactions.
-	minprice := gasprice(self.gasPrice, pct)
 	for _, tx := range transactions {
 		// We can skip err. It has already been validated in the tx pool
 		from, _ := tx.From()
 
 		// check if it falls within margin
-		if tx.GasPrice().Cmp(minprice) < 0 {
+		if tx.GasPrice().Cmp(self.gasPrice) < 0 {
 			// ignore the transaction and transactor. We ignore the transactor
 			// because nonce will fail after ignoring this transaction so there's
 			// no point
-			ignoredTransactors.Add(from)
-			glog.V(logger.Info).Infof("transaction(%x) below gas price (<%d%% ask price). All sequential txs from this address(%x) will fail\n", tx.Hash().Bytes()[:4], pct, from[:4])
+			lowGasTransactors.Add(from)
+
+			glog.V(logger.Info).Infof("transaction(%x) below gas price (tx=%v ask=%v). All sequential txs from this address(%x) will be ignored\n", tx.Hash().Bytes()[:4], common.CurrencyToString(tx.GasPrice()), common.CurrencyToString(self.gasPrice), from[:4])
+		}
+
+		// Continue with the next transaction if the transaction sender is included in
+		// the low gas tx set. This will also remove the tx and all sequential transaction
+		// from this transactor
+		if lowGasTransactors.Has(from) {
+			// add tx to the low gas set. This will be removed at the end of the run
+			// owned accounts are ignored
+			if !ownedAccounts.Has(from) {
+				lowGasTxs = append(lowGasTxs, tx)
+			}
 			continue
 		}
 
@@ -327,6 +346,7 @@ func (self *worker) commitNewWork() {
 			tcount++
 		}
 	}
+	self.eth.TxPool().RemoveTransactions(lowGasTxs)
 
 	var (
 		uncles    []*types.Header
@@ -423,3 +443,11 @@ func gasprice(price *big.Int, pct int64) *big.Int {
 	p.Mul(p, big.NewInt(pct))
 	return p
 }
+
+func accountAddressesSet(accounts []accounts.Account) *set.Set {
+	accountSet := set.New()
+	for _, account := range accounts {
+		accountSet.Add(common.BytesToAddress(account.Address))
+	}
+	return accountSet
+}
