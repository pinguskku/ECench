commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
commit cc436c4b28c95f825499d67c92a18de5d27e90c2
Author: obscuren <geffobscura@gmail.com>
Date:   Sat Apr 18 02:21:07 2015 +0200

    eth: additional cleanups to the subprotocol, improved block propagation
    
    * Improved block propagation by sending blocks only to peers to which, as
      far as we know, the peer does not know about.
    * Made sub protocol its own manager
    * SubProtocol now contains the p2p.Protocol which is used instead of
      a function-returning-protocol thing.

diff --git a/eth/backend.go b/eth/backend.go
index d34a2d26b..923cdfa5d 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -127,19 +127,20 @@ type Ethereum struct {
 
 	//*** SERVICES ***
 	// State manager for processing new blocks and managing the over all states
-	blockProcessor *core.BlockProcessor
-	txPool         *core.TxPool
-	chainManager   *core.ChainManager
-	accountManager *accounts.Manager
-	whisper        *whisper.Whisper
-	pow            *ethash.Ethash
-	downloader     *downloader.Downloader
+	blockProcessor  *core.BlockProcessor
+	txPool          *core.TxPool
+	chainManager    *core.ChainManager
+	accountManager  *accounts.Manager
+	whisper         *whisper.Whisper
+	pow             *ethash.Ethash
+	protocolManager *ProtocolManager
+	downloader      *downloader.Downloader
 
 	net      *p2p.Server
 	eventMux *event.TypeMux
 	txSub    event.Subscription
-	blockSub event.Subscription
-	miner    *miner.Miner
+	//blockSub event.Subscription
+	miner *miner.Miner
 
 	// logger logger.LogSystem
 
@@ -216,14 +217,14 @@ func New(config *Config) (*Ethereum, error) {
 	eth.whisper = whisper.New()
 	eth.shhVersionId = int(eth.whisper.Version())
 	eth.miner = miner.New(eth, eth.pow, config.MinerThreads)
+	eth.protocolManager = NewProtocolManager(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
 
 	netprv, err := config.nodeKey()
 	if err != nil {
 		return nil, err
 	}
 
-	ethProto := EthProtocol(config.ProtocolVersion, config.NetworkId, eth.txPool, eth.chainManager, eth.downloader)
-	protocols := []p2p.Protocol{ethProto}
+	protocols := []p2p.Protocol{eth.protocolManager.SubProtocol}
 	if config.Shh {
 		protocols = append(protocols, eth.whisper.Protocol())
 	}
@@ -386,7 +387,7 @@ func (s *Ethereum) Start() error {
 	go s.txBroadcastLoop()
 
 	// broadcast mined blocks
-	s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
+	//s.blockSub = s.eventMux.Subscribe(core.ChainHeadEvent{})
 	go s.blockBroadcastLoop()
 
 	glog.V(logger.Info).Infoln("Server started")
@@ -418,8 +419,8 @@ func (s *Ethereum) Stop() {
 	defer s.stateDb.Close()
 	defer s.extraDb.Close()
 
-	s.txSub.Unsubscribe()    // quits txBroadcastLoop
-	s.blockSub.Unsubscribe() // quits blockBroadcastLoop
+	s.txSub.Unsubscribe() // quits txBroadcastLoop
+	//s.blockSub.Unsubscribe() // quits blockBroadcastLoop
 
 	s.txPool.Stop()
 	s.eventMux.Stop()
@@ -463,12 +464,14 @@ func (self *Ethereum) syncAccounts(tx *types.Transaction) {
 
 func (self *Ethereum) blockBroadcastLoop() {
 	// automatically stops if unsubscribe
-	for obj := range self.blockSub.Chan() {
-		switch ev := obj.(type) {
-		case core.ChainHeadEvent:
-			self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+	/*
+		for obj := range self.blockSub.Chan() {
+			switch ev := obj.(type) {
+			case core.ChainHeadEvent:
+				self.net.BroadcastLimited("eth", NewBlockMsg, math.Sqrt, []interface{}{ev.Block, ev.Block.Td})
+			}
 		}
-	}
+	*/
 }
 
 func saveProtocolVersion(db common.Database, protov int) {
diff --git a/eth/handler.go b/eth/handler.go
index b3890d365..858ae2958 100644
--- a/eth/handler.go
+++ b/eth/handler.go
@@ -1,10 +1,46 @@
 package eth
 
+// XXX Fair warning, most of the code is re-used from the old protocol. Please be aware that most of this will actually change
+// The idea is that most of the calls within the protocol will become synchronous.
+// Block downloading and block processing will be complete seperate processes
+/*
+# Possible scenarios
+
+// Synching scenario
+// Use the best peer to synchronise
+blocks, err := pm.downloader.Synchronise()
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+// Receiving block with known parent
+if parent_exist {
+	if err := pm.chainman.InsertChain(block); err != nil {
+		// handle
+		break
+	}
+	pm.BroadcastBlock(block)
+}
+
+// Receiving block with unknown parent
+blocks, err := pm.downloader.SynchroniseWithPeer(peer)
+if err != nil {
+	// handle
+	break
+}
+pm.chainman.InsertChain(blocks)
+
+*/
+
 import (
 	"fmt"
+	"math"
 	"sync"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/core"
 	"github.com/ethereum/go-ethereum/core/types"
 	"github.com/ethereum/go-ethereum/eth/downloader"
 	"github.com/ethereum/go-ethereum/logger"
@@ -17,27 +53,6 @@ func errResp(code errCode, format string, v ...interface{}) error {
 	return fmt.Errorf("%v - %v", code, fmt.Sprintf(format, v...))
 }
 
-// main entrypoint, wrappers starting a server running the eth protocol
-// use this constructor to attach the protocol ("class") to server caps
-// the Dev p2p layer then runs the protocol instance on each peer
-func EthProtocol(protocolVersion, networkId int, txPool txPool, chainManager chainManager, downloader *downloader.Downloader) p2p.Protocol {
-	protocol := newProtocolManager(txPool, chainManager, downloader)
-
-	return p2p.Protocol{
-		Name:    "eth",
-		Version: uint(protocolVersion),
-		Length:  ProtocolLength,
-		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
-			//return runEthProtocol(protocolVersion, networkId, txPool, chainManager, downloader, p, rw)
-			peer := protocol.newPeer(protocolVersion, networkId, p, rw)
-			err := protocol.handle(peer)
-			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
-
-			return err
-		},
-	}
-}
-
 type hashFetcherFn func(common.Hash) error
 type blockFetcherFn func([]common.Hash) error
 
@@ -51,44 +66,66 @@ type extProt struct {
 func (ep extProt) GetHashes(hash common.Hash) error    { return ep.getHashes(hash) }
 func (ep extProt) GetBlock(hashes []common.Hash) error { return ep.getBlocks(hashes) }
 
-type EthProtocolManager struct {
+type ProtocolManager struct {
 	protVer, netId int
 	txpool         txPool
-	chainman       chainManager
+	chainman       *core.ChainManager
 	downloader     *downloader.Downloader
 
 	pmu   sync.Mutex
 	peers map[string]*peer
+
+	SubProtocol p2p.Protocol
 }
 
-func newProtocolManager(txpool txPool, chainman chainManager, downloader *downloader.Downloader) *EthProtocolManager {
-	return &EthProtocolManager{
+// NewProtocolManager returns a new ethereum sub protocol manager. The Ethereum sub protocol manages peers capable
+// with the ethereum network.
+func NewProtocolManager(protocolVersion, networkId int, txpool txPool, chainman *core.ChainManager, downloader *downloader.Downloader) *ProtocolManager {
+	manager := &ProtocolManager{
 		txpool:     txpool,
 		chainman:   chainman,
 		downloader: downloader,
 		peers:      make(map[string]*peer),
 	}
+
+	manager.SubProtocol = p2p.Protocol{
+		Name:    "eth",
+		Version: uint(protocolVersion),
+		Length:  ProtocolLength,
+		Run: func(p *p2p.Peer, rw p2p.MsgReadWriter) error {
+			peer := manager.newPeer(protocolVersion, networkId, p, rw)
+			err := manager.handle(peer)
+			glog.V(logger.Detail).Infof("[%s]: %v\n", peer.id, err)
+
+			return err
+		},
+	}
+
+	return manager
 }
 
-func (pm *EthProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
-	pm.pmu.Lock()
-	defer pm.pmu.Unlock()
+func (pm *ProtocolManager) newPeer(pv, nv int, p *p2p.Peer, rw p2p.MsgReadWriter) *peer {
 
 	td, current, genesis := pm.chainman.Status()
 
-	peer := newPeer(pv, nv, genesis, current, td, p, rw)
-	pm.peers[peer.id] = peer
-
-	return peer
+	return newPeer(pv, nv, genesis, current, td, p, rw)
 }
 
-func (pm *EthProtocolManager) handle(p *peer) error {
+func (pm *ProtocolManager) handle(p *peer) error {
 	if err := p.handleStatus(); err != nil {
 		return err
 	}
+	pm.pmu.Lock()
+	pm.peers[p.id] = p
+	pm.pmu.Unlock()
 
 	pm.downloader.RegisterPeer(p.id, p.td, p.currentHash, p.requestHashes, p.requestBlocks)
-	defer pm.downloader.UnregisterPeer(p.id)
+	defer func() {
+		pm.pmu.Lock()
+		defer pm.pmu.Unlock()
+		delete(pm.peers, p.id)
+		pm.downloader.UnregisterPeer(p.id)
+	}()
 
 	// propagate existing transactions. new transactions appearing
 	// after this will be sent via broadcasts.
@@ -106,7 +143,7 @@ func (pm *EthProtocolManager) handle(p *peer) error {
 	return nil
 }
 
-func (self *EthProtocolManager) handleMsg(p *peer) error {
+func (self *ProtocolManager) handleMsg(p *peer) error {
 	msg, err := p.rw.ReadMsg()
 	if err != nil {
 		return err
@@ -192,7 +229,6 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 		var blocks []*types.Block
 		if err := msgStream.Decode(&blocks); err != nil {
 			glog.V(logger.Detail).Infoln("Decode error", err)
-			fmt.Println("decode error", err)
 			blocks = nil
 		}
 		self.downloader.DeliverChunk(p.id, blocks)
@@ -206,6 +242,10 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			return errResp(ErrDecode, "block validation %v: %v", msg, err)
 		}
 		hash := request.Block.Hash()
+		// Add the block hash as a known hash to the peer. This will later be used to detirmine
+		// who should receive this.
+		p.blockHashes.Add(hash)
+
 		_, chainHead, _ := self.chainman.Status()
 
 		jsonlogger.LogJson(&logger.EthChainReceivedNewBlock{
@@ -215,10 +255,45 @@ func (self *EthProtocolManager) handleMsg(p *peer) error {
 			BlockPrevHash: request.Block.ParentHash().Hex(),
 			RemoteId:      p.ID().String(),
 		})
-		self.downloader.AddBlock(p.id, request.Block, request.TD)
 
+		// Attempt to insert the newly received by checking if the parent exists.
+		// if the parent exists we process the block and propagate to our peers
+		// if the parent does not exists we delegate to the downloader.
+		// NOTE we can reduce chatter by dropping blocks with Td < currentTd
+		if self.chainman.HasBlock(request.Block.ParentHash()) {
+			if err := self.chainman.InsertChain(types.Blocks{request.Block}); err != nil {
+				// handle error
+				return nil
+			}
+			self.BroadcastBlock(hash, request.Block)
+		} else {
+			self.downloader.AddBlock(p.id, request.Block, request.TD)
+		}
 	default:
 		return errResp(ErrInvalidMsgCode, "%v", msg.Code)
 	}
 	return nil
 }
+
+// BroadcastBlock will propagate the block to its connected peers. It will sort
+// out which peers do not contain the block in their block set and will do a
+// sqrt(peers) to determine the amount of peers we broadcast to.
+func (pm *ProtocolManager) BroadcastBlock(hash common.Hash, block *types.Block) {
+	pm.pmu.Lock()
+	defer pm.pmu.Unlock()
+
+	// Find peers who don't know anything about the given hash. Peers that
+	// don't know about the hash will be a candidate for the broadcast loop
+	var peers []*peer
+	for _, peer := range pm.peers {
+		if !peer.blockHashes.Has(hash) {
+			peers = append(peers, peer)
+		}
+	}
+	// Broadcast block to peer set
+	peers = peers[:int(math.Sqrt(float64(len(peers))))]
+	for _, peer := range peers {
+		peer.sendNewBlock(block)
+	}
+	glog.V(logger.Detail).Infoln("broadcast block to", len(peers), "peers")
+}
diff --git a/eth/peer.go b/eth/peer.go
index db7fea7a7..8cedbd85a 100644
--- a/eth/peer.go
+++ b/eth/peer.go
@@ -78,6 +78,12 @@ func (p *peer) sendBlocks(blocks []*types.Block) error {
 	return p2p.Send(p.rw, BlocksMsg, blocks)
 }
 
+func (p *peer) sendNewBlock(block *types.Block) error {
+	p.blockHashes.Add(block.Hash())
+
+	return p2p.Send(p.rw, NewBlockMsg, []interface{}{block, block.Td})
+}
+
 func (p *peer) requestHashes(from common.Hash) error {
 	p.Debugf("fetching hashes (%d) %x...\n", maxHashes, from[0:4])
 	return p2p.Send(p.rw, GetBlockHashesMsg, getBlockHashesMsgData{from, maxHashes})
