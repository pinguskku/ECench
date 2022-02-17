commit c3f238dd5371961d309350fb0f9d5136c9fc6afa
Author: Zsolt Felföldi <zsfelfoldi@gmail.com>
Date:   Mon Feb 5 14:41:53 2018 +0100

    les: limit LES peer count and improve peer configuration logic (#16010)
    
    * les: limit number of LES connections
    
    * eth, cmd/utils: light vs max peer configuration logic

diff --git a/cmd/utils/flags.go b/cmd/utils/flags.go
index 58bb95243..833cd95de 100644
--- a/cmd/utils/flags.go
+++ b/cmd/utils/flags.go
@@ -179,7 +179,7 @@ var (
 	LightPeersFlag = cli.IntFlag{
 		Name:  "lightpeers",
 		Usage: "Maximum number of LES client peers",
-		Value: 20,
+		Value: eth.DefaultConfig.LightPeers,
 	}
 	LightKDFFlag = cli.BoolFlag{
 		Name:  "lightkdf",
@@ -791,20 +791,40 @@ func SetP2PConfig(ctx *cli.Context, cfg *p2p.Config) {
 	setBootstrapNodes(ctx, cfg)
 	setBootstrapNodesV5(ctx, cfg)
 
+	lightClient := ctx.GlobalBool(LightModeFlag.Name) || ctx.GlobalString(SyncModeFlag.Name) == "light"
+	lightServer := ctx.GlobalInt(LightServFlag.Name) != 0
+	lightPeers := ctx.GlobalInt(LightPeersFlag.Name)
+
 	if ctx.GlobalIsSet(MaxPeersFlag.Name) {
 		cfg.MaxPeers = ctx.GlobalInt(MaxPeersFlag.Name)
+	} else {
+		if lightServer {
+			cfg.MaxPeers += lightPeers
+		}
+		if lightClient && ctx.GlobalIsSet(LightPeersFlag.Name) && cfg.MaxPeers < lightPeers {
+			cfg.MaxPeers = lightPeers
+		}
 	}
+	if !(lightClient || lightServer) {
+		lightPeers = 0
+	}
+	ethPeers := cfg.MaxPeers - lightPeers
+	if lightClient {
+		ethPeers = 0
+	}
+	log.Info("Maximum peer count", "ETH", ethPeers, "LES", lightPeers, "total", cfg.MaxPeers)
+
 	if ctx.GlobalIsSet(MaxPendingPeersFlag.Name) {
 		cfg.MaxPendingPeers = ctx.GlobalInt(MaxPendingPeersFlag.Name)
 	}
-	if ctx.GlobalIsSet(NoDiscoverFlag.Name) || ctx.GlobalBool(LightModeFlag.Name) {
+	if ctx.GlobalIsSet(NoDiscoverFlag.Name) || lightClient {
 		cfg.NoDiscovery = true
 	}
 
 	// if we're running a light client or server, force enable the v5 peer discovery
 	// unless it is explicitly disabled with --nodiscover note that explicitly specifying
 	// --v5disc overrides --nodiscover, in which case the later only disables v4 discovery
-	forceV5Discovery := (ctx.GlobalBool(LightModeFlag.Name) || ctx.GlobalInt(LightServFlag.Name) > 0) && !ctx.GlobalBool(NoDiscoverFlag.Name)
+	forceV5Discovery := (lightClient || lightServer) && !ctx.GlobalBool(NoDiscoverFlag.Name)
 	if ctx.GlobalIsSet(DiscoveryV5Flag.Name) {
 		cfg.DiscoveryV5 = ctx.GlobalBool(DiscoveryV5Flag.Name)
 	} else if forceV5Discovery {
diff --git a/eth/backend.go b/eth/backend.go
index c39974a2c..bcd724c0c 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -393,10 +393,10 @@ func (s *Ethereum) Start(srvr *p2p.Server) error {
 	// Figure out a max peers count based on the server limits
 	maxPeers := srvr.MaxPeers
 	if s.config.LightServ > 0 {
-		maxPeers -= s.config.LightPeers
-		if maxPeers < srvr.MaxPeers/2 {
-			maxPeers = srvr.MaxPeers / 2
+		if s.config.LightPeers >= srvr.MaxPeers {
+			return fmt.Errorf("invalid peer config: light peer count (%d) >= total peer count (%d)", s.config.LightPeers, srvr.MaxPeers)
 		}
+		maxPeers -= s.config.LightPeers
 	}
 	// Start the networking layer and the light server if requested
 	s.protocolManager.Start(maxPeers)
diff --git a/eth/config.go b/eth/config.go
index 4399560fa..2158c71ba 100644
--- a/eth/config.go
+++ b/eth/config.go
@@ -43,7 +43,7 @@ var DefaultConfig = Config{
 		DatasetsOnDisk: 2,
 	},
 	NetworkId:     1,
-	LightPeers:    20,
+	LightPeers:    100,
 	DatabaseCache: 128,
 	GasPrice:      big.NewInt(18 * params.Shannon),
 
diff --git a/les/backend.go b/les/backend.go
index 798e44e85..6a324cb04 100644
--- a/les/backend.go
+++ b/les/backend.go
@@ -46,6 +46,8 @@ import (
 )
 
 type LightEthereum struct {
+	config *eth.Config
+
 	odr         *LesOdr
 	relay       *LesTxRelay
 	chainConfig *params.ChainConfig
@@ -92,6 +94,7 @@ func New(ctx *node.ServiceContext, config *eth.Config) (*LightEthereum, error) {
 	quitSync := make(chan struct{})
 
 	leth := &LightEthereum{
+		config:           config,
 		chainConfig:      chainConfig,
 		chainDb:          chainDb,
 		eventMux:         ctx.EventMux,
@@ -224,7 +227,7 @@ func (s *LightEthereum) Start(srvr *p2p.Server) error {
 	// clients are searching for the first advertised protocol in the list
 	protocolVersion := AdvertiseProtocolVersions[0]
 	s.serverPool.start(srvr, lesTopic(s.blockchain.Genesis().Hash(), protocolVersion))
-	s.protocolManager.Start()
+	s.protocolManager.Start(s.config.LightPeers)
 	return nil
 }
 
diff --git a/les/handler.go b/les/handler.go
index ad2e8058f..8cd37c7ab 100644
--- a/les/handler.go
+++ b/les/handler.go
@@ -109,6 +109,7 @@ type ProtocolManager struct {
 	downloader *downloader.Downloader
 	fetcher    *lightFetcher
 	peers      *peerSet
+	maxPeers   int
 
 	SubProtocols []p2p.Protocol
 
@@ -216,7 +217,9 @@ func (pm *ProtocolManager) removePeer(id string) {
 	pm.peers.Unregister(id)
 }
 
-func (pm *ProtocolManager) Start() {
+func (pm *ProtocolManager) Start(maxPeers int) {
+	pm.maxPeers = maxPeers
+
 	if pm.lightSync {
 		go pm.syncer()
 	} else {
@@ -257,6 +260,10 @@ func (pm *ProtocolManager) newPeer(pv int, nv uint64, p *p2p.Peer, rw p2p.MsgRea
 // handle is the callback invoked to manage the life cycle of a les peer. When
 // this function terminates, the peer is disconnected.
 func (pm *ProtocolManager) handle(p *peer) error {
+	if pm.peers.Len() >= pm.maxPeers {
+		return p2p.DiscTooManyPeers
+	}
+
 	p.Log().Debug("Light Ethereum peer connected", "name", p.Name())
 
 	// Execute the LES handshake
diff --git a/les/helper_test.go b/les/helper_test.go
index 57e693996..1c1de64ad 100644
--- a/les/helper_test.go
+++ b/les/helper_test.go
@@ -176,7 +176,7 @@ func newTestProtocolManager(lightSync bool, blocks int, generator func(int, *cor
 		srv.fcManager = flowcontrol.NewClientManager(50, 10, 1000000000)
 		srv.fcCostStats = newCostStats(nil)
 	}
-	pm.Start()
+	pm.Start(1000)
 	return pm, nil
 }
 
diff --git a/les/server.go b/les/server.go
index ec2e44fec..85ebbf898 100644
--- a/les/server.go
+++ b/les/server.go
@@ -38,6 +38,7 @@ import (
 )
 
 type LesServer struct {
+	config          *eth.Config
 	protocolManager *ProtocolManager
 	fcManager       *flowcontrol.ClientManager // nil if our node is client only
 	fcCostStats     *requestCostStats
@@ -62,6 +63,7 @@ func NewLesServer(eth *eth.Ethereum, config *eth.Config) (*LesServer, error) {
 	}
 
 	srv := &LesServer{
+		config:           config,
 		protocolManager:  pm,
 		quitSync:         quitSync,
 		lesTopics:        lesTopics,
@@ -108,7 +110,7 @@ func (s *LesServer) Protocols() []p2p.Protocol {
 
 // Start starts the LES server
 func (s *LesServer) Start(srvr *p2p.Server) {
-	s.protocolManager.Start()
+	s.protocolManager.Start(s.config.LightPeers)
 	for _, topic := range s.lesTopics {
 		topic := topic
 		go func() {
