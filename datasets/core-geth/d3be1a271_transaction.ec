commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit d3be1a271961f13f5bd056d195b790c668552fe1
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Wed Apr 22 17:56:06 2015 +0200

    eth: moved mined, tx events to protocol-hnd and improved tx propagation
    
    Transactions are now propagated to peers from which we have not yet
    received the transaction. This will significantly reduce the chatter on
    the network.
    
    Moved new mined block handler to the protocol handler and moved
    transaction handling to protocol handler.

diff --git a/core/transaction_pool.go b/core/transaction_pool.go
index bc6e70c7a..9c175e568 100644
--- a/core/transaction_pool.go
+++ b/core/transaction_pool.go
@@ -229,8 +229,10 @@ func (self *TxPool) queueTx(tx *types.Transaction) {
 func (pool *TxPool) addTx(tx *types.Transaction) {
 	if _, ok := pool.txs[tx.Hash()]; !ok {
 		pool.txs[tx.Hash()] = tx
-		// Notify the subscribers
-		pool.eventMux.Post(TxPreEvent{tx})
+		// Notify the subscribers. This event is posted in a goroutine
+		// because it's possible that somewhere during the post "Remove transaction"
+		// gets called which will then wait for the global tx pool lock and deadlock.
+		go pool.eventMux.Post(TxPreEvent{tx})
 	}
 }
 
diff --git a/eth/backend.go b/eth/backend.go
index a2c0baf8b..646a4eaf2 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -3,7 +3,6 @@ package eth
 import (
 	"crypto/ecdsa"
 	"fmt"
-	"math"
 	"path"
 	"strings"
 
@@ -136,11 +135,10 @@ type Ethereum struct {
 	protocolManager *ProtocolManager
 	downloader      *downloader.Downloader
 
-	net           *p2p.Server
-	eventMux      *event.TypeMux
-	txSub         event.Subscription
-	minedBlockSub event.Subscription
-	miner         *miner.Miner
+	net      *p2p.Server
+	eventMux *event.TypeMux
+	txSub    event.Subscription
+	miner    *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -222,7 +220,7 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
-	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.eventMux, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
@@ -380,6 +378,7 @@ func (s *Ethereum) Start() error {
 
 	// Start services
 	go s.txPool.Start()
+	s.protocolManager.Start()
 
 	if s.whisper != nil {
 		s.whisper.Start()
@@ -389,10 +388,6 @@ func (s *Ethereum) Start() error {
 	s.txSub = s.eventMux.Subscribe(core.TxPreEvent{})
 	go s.txBroadcastLoop()
 
-	// broadcast mined blocks
-	s.minedBlockSub = s.eventMux.Subscribe(core.NewMinedBlockEvent{})
-	go s.minedBroadcastLoop()
-
 	glog.V(logger.Info).Infoln("Server started")
 	return nil
 }
@@ -422,9 +417,9 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()         // quits txBroadcastLoop
-	s.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
 
+	s.protocolManager.Stop()
 	s.txPool.Stop()
 	s.eventMux.Stop()
 	if s.whisper != nil {
@@ -440,13 +435,10 @@ func (s *Ethereum) WaitForShutdown() {
 	<-s.shutdownChan
 }
 
-// now tx broadcasting is taken out of txPool
-// handled here via subscription, efficiency?
 func (self *Ethereum) txBroadcastLoop() {
 	// automatically stops if unsubscribe
 	for obj := range self.txSub.Chan() {
 		event := obj.(core.TxPreEvent)
-		self.net.BroadcastLimited("eth", TxMsg, math.Sqrt, []*types.Transaction{event.Tx})
 		self.syncAccounts(event.Tx)
 	}
 }
@@ -465,16 +457,6 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 	}
 }
 
-func (self *Ethereum) minedBroadcastLoop() {
-	// automatically stops if unsubscribe
-	for obj := range self.minedBlockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.NewMinedBlockEvent:
-			self.protocolManager.BroadcastBlock(ev.Block.Hash(), ev.Block)
-		}
-	}
-}
-
 func saveProtocolVersion(db common.Database, protov int) {
 	d, _ := db.Get([]byte("ProtocolVersion"))
 	protocolVersion := common.NewValue(d).Uint()
diff --git a/eth/handler.go b/eth/handler.go
index 622f22132..d466dbfee 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -44,6 +44,7 @@ import (
 	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
+	"github.com/ethereum/go-ethereum/event"
 	"github.com/ethereum/go-ethereum/logger"
 	"github.com/ethereum/go-ethereum/logger/glog"
 	"github.com/ethereum/go-ethereum/p2p"
@@ -77,12 +78,17 @@ type ProtocolManager struct {
 	peers map[string]*peer
 
 	SubProtocol p2p.Protocol
+
+	eventMux      *event.TypeMux
+	txSub         event.Subscription
+	minedBlockSub event.Subscription
 }
 
 // NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
 // with the ethereum network.
-func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+func NewProtocolManager(protocolVersion, networkId int, mux *event.TypeMux, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
 	manager := &ProtocolManager{
+		eventMux:   mux,
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
@@ -105,6 +111,21 @@ func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman
 	return manager
 }
 
+func (pm *ProtocolManager) Start() {
+	// broadcast transactions
+	pm.txSub = pm.eventMux.Subscribe(core.TxPreEvent{})
+	go pm.txBroadcastLoop()
+
+	// broadcast mined blocks
+	pm.minedBlockSub = pm.eventMux.Subscribe(core.NewMinedBlockEvent{})
+	go pm.minedBroadcastLoop()
+}
+
+func (pm *ProtocolManager) Stop() {
+	pm.txSub.Unsubscribe()         // quits txBroadcastLoop
+	pm.minedBlockSub.Unsubscribe() // quits blockBroadcastLoop
+}
+
 func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
@@ -326,10 +347,51 @@ func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block)
 		}
 	}
 	// Broadcast block to peer set
-	// XXX due to the current shit state of the network disable the limit
 	peers = peers[:int(math.Sqrt(float64(len(peers))))]
 	for _, peer := range peers {
 		peer.sendNewBlock(block)
 	}
 	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
 }
+
+// BroadcastTx will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastTx(hash common.Hash, tx *types.Transaction) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.txHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendTransaction(tx)
+	}
+	glog.V(logger.Detail).Infoln("broadcast tx to", len(peers), "peers")
+}
+
+// Mined broadcast loop
+func (self *ProtocolManager) minedBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.minedBlockSub.Chan() {
+		switch ev := obj.(type) {
+		case core.NewMinedBlockEvent:
+			self.BroadcastBlock(ev.Block.Hash(), ev.Block)
+		}
+	}
+}
+
+func (self *ProtocolManager) txBroadcastLoop() {
+	// automatically stops if unsubscribe
+	for obj := range self.txSub.Chan() {
+		event := obj.(core.TxPreEvent)
+		self.BroadcastTx(event.Tx.Hash(), event.Tx)
+	}
+}
diff --git a/eth/peer.go b/eth/peer.go
index 972880845..ec0c4b1f3 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -86,6 +86,12 @@ func (p *peer) sendNewBlock(block *types.Block) error {
 	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
 }
 
+func (p *peer) sendTransaction(tx *types.Transaction) error {
+	p.txHashes.Add(tx.Hash())
+
+	return p2p.Send(p.rw, TxMsg, []*types.Transaction{tx})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	glog.V(logger.Debug).Infof("[%s] fetching hashes (%d) %x...\n", p.id, maxHashes, from[:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
