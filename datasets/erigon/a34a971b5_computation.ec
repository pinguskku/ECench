commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
commit a34a971b508e1bc1fbeb3c2d02cbb8686d2491d8
Author: obscuren <geffobscura@gmail.com>
Date:   Thu Oct 2 01:36:59 2014 +0200

    improved blockchain downloading

diff --git a/block_pool.go b/block_pool.go
index 2dbe11069..f5c53b9f7 100644
--- a/block_pool.go
+++ b/block_pool.go
@@ -217,9 +217,7 @@ out:
 				}
 			})
 
-			if !self.fetchingHashes && len(self.hashPool) > 0 {
-				self.DistributeHashes()
-			}
+			self.DistributeHashes()
 
 			if self.ChainLength < len(self.hashPool) {
 				self.ChainLength = len(self.hashPool)
diff --git a/peer.go b/peer.go
index 318294509..b8f850b5a 100644
--- a/peer.go
+++ b/peer.go
@@ -129,9 +129,9 @@ type Peer struct {
 	statusKnown  bool
 
 	// Last received pong message
-	lastPong          int64
-	lastBlockReceived time.Time
-	LastHashReceived  time.Time
+	lastPong           int64
+	lastBlockReceived  time.Time
+	doneFetchingHashes bool
 
 	host             []byte
 	port             uint16
@@ -164,36 +164,38 @@ func NewPeer(conn net.Conn, ethereum *Ethereum, inbound bool) *Peer {
 	pubkey := ethereum.KeyManager().PublicKey()[1:]
 
 	return &Peer{
-		outputQueue:     make(chan *ethwire.Msg, outputBufferSize),
-		quit:            make(chan bool),
-		ethereum:        ethereum,
-		conn:            conn,
-		inbound:         inbound,
-		disconnect:      0,
-		connected:       1,
-		port:            30303,
-		pubkey:          pubkey,
-		blocksRequested: 10,
-		caps:            ethereum.ServerCaps(),
-		version:         ethereum.ClientIdentity().String(),
-		protocolCaps:    ethutil.NewValue(nil),
-		td:              big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		conn:               conn,
+		inbound:            inbound,
+		disconnect:         0,
+		connected:          1,
+		port:               30303,
+		pubkey:             pubkey,
+		blocksRequested:    10,
+		caps:               ethereum.ServerCaps(),
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 }
 
 func NewOutboundPeer(addr string, ethereum *Ethereum, caps Caps) *Peer {
 	p := &Peer{
-		outputQueue:  make(chan *ethwire.Msg, outputBufferSize),
-		quit:         make(chan bool),
-		ethereum:     ethereum,
-		inbound:      false,
-		connected:    0,
-		disconnect:   0,
-		port:         30303,
-		caps:         caps,
-		version:      ethereum.ClientIdentity().String(),
-		protocolCaps: ethutil.NewValue(nil),
-		td:           big.NewInt(0),
+		outputQueue:        make(chan *ethwire.Msg, outputBufferSize),
+		quit:               make(chan bool),
+		ethereum:           ethereum,
+		inbound:            false,
+		connected:          0,
+		disconnect:         0,
+		port:               30303,
+		caps:               caps,
+		version:            ethereum.ClientIdentity().String(),
+		protocolCaps:       ethutil.NewValue(nil),
+		td:                 big.NewInt(0),
+		doneFetchingHashes: true,
 	}
 
 	// Set up the connection in another goroutine so we don't block the main thread
@@ -503,20 +505,22 @@ func (p *Peer) HandleInbound() {
 					it := msg.Data.NewIterator()
 					for it.Next() {
 						hash := it.Value().Bytes()
+						p.lastReceivedHash = hash
+
 						if blockPool.HasCommonHash(hash) {
 							foundCommonHash = true
 
 							break
 						}
 
-						p.lastReceivedHash = hash
-						p.LastHashReceived = time.Now()
-
 						blockPool.AddHash(hash, p)
 					}
 
 					if !foundCommonHash && msg.Data.Len() != 0 {
 						p.FetchHashes()
+					} else {
+						peerlogger.Infof("Found common hash (%x...)\n", p.lastReceivedHash[0:4])
+						p.doneFetchingHashes = true
 					}
 
 				case ethwire.MsgBlockTy:
@@ -543,11 +547,15 @@ func (p *Peer) HandleInbound() {
 
 func (self *Peer) FetchBlocks(hashes [][]byte) {
 	if len(hashes) > 0 {
+		peerlogger.Debugf("Fetching blocks (%d)\n", len(hashes))
+
 		self.QueueMessage(ethwire.NewMessage(ethwire.MsgGetBlocksTy, ethutil.ByteSliceToInterface(hashes)))
 	}
 }
 
 func (self *Peer) FetchHashes() {
+	self.doneFetchingHashes = false
+
 	blockPool := self.ethereum.blockPool
 
 	if self.td.Cmp(self.ethereum.HighestTDPeer()) >= 0 {
@@ -562,7 +570,7 @@ func (self *Peer) FetchHashes() {
 }
 
 func (self *Peer) FetchingHashes() bool {
-	return time.Since(self.LastHashReceived) < 200*time.Millisecond
+	return !self.doneFetchingHashes
 }
 
 // General update method
@@ -576,10 +584,9 @@ out:
 			if self.IsCap("eth") {
 				var (
 					sinceBlock = time.Since(self.lastBlockReceived)
-					sinceHash  = time.Since(self.LastHashReceived)
 				)
 
-				if sinceBlock > 5*time.Second && sinceHash > 5*time.Second {
+				if sinceBlock > 5*time.Second {
 					self.catchingUp = false
 				}
 			}
