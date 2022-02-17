commit a5a9feab21cf5af36f2790bc4c5d928e4c7b7608
Author: ucwong <ucwong@126.com>
Date:   Wed Apr 1 17:35:26 2020 +0800

    whisper: fix whisper go routine leak with sync wait group (#20844)

diff --git a/whisper/whisperv6/peer.go b/whisper/whisperv6/peer.go
index 29d8bdf17..68fa7c8cb 100644
--- a/whisper/whisperv6/peer.go
+++ b/whisper/whisperv6/peer.go
@@ -44,6 +44,8 @@ type Peer struct {
 	known mapset.Set // Messages already known by the peer to avoid wasting bandwidth
 
 	quit chan struct{}
+
+	wg sync.WaitGroup
 }
 
 // newPeer creates a new whisper peer object, but does not run the handshake itself.
@@ -64,6 +66,7 @@ func newPeer(host *Whisper, remote *p2p.Peer, rw p2p.MsgReadWriter) *Peer {
 // start initiates the peer updater, periodically broadcasting the whisper packets
 // into the network.
 func (peer *Peer) start() {
+	peer.wg.Add(1)
 	go peer.update()
 	log.Trace("start", "peer", peer.ID())
 }
@@ -71,6 +74,7 @@ func (peer *Peer) start() {
 // stop terminates the peer updater, stopping message forwarding to it.
 func (peer *Peer) stop() {
 	close(peer.quit)
+	peer.wg.Wait()
 	log.Trace("stop", "peer", peer.ID())
 }
 
@@ -81,7 +85,9 @@ func (peer *Peer) handshake() error {
 	errc := make(chan error, 1)
 	isLightNode := peer.host.LightClientMode()
 	isRestrictedLightNodeConnection := peer.host.LightClientModeConnectionRestricted()
+	peer.wg.Add(1)
 	go func() {
+		defer peer.wg.Done()
 		pow := peer.host.MinPow()
 		powConverted := math.Float64bits(pow)
 		bloom := peer.host.BloomFilter()
@@ -144,6 +150,7 @@ func (peer *Peer) handshake() error {
 // update executes periodic operations on the peer, including message transmission
 // and expiration.
 func (peer *Peer) update() {
+	defer peer.wg.Done()
 	// Start the tickers for the updates
 	expire := time.NewTicker(expirationCycle)
 	defer expire.Stop()
diff --git a/whisper/whisperv6/whisper.go b/whisper/whisperv6/whisper.go
index a7787ca69..e9c872a99 100644
--- a/whisper/whisperv6/whisper.go
+++ b/whisper/whisperv6/whisper.go
@@ -88,6 +88,8 @@ type Whisper struct {
 	stats   Statistics // Statistics of whisper node
 
 	mailServer MailServer // MailServer interface
+
+	wg sync.WaitGroup
 }
 
 // New creates a Whisper client ready to communicate through the Ethereum P2P network.
@@ -243,8 +245,10 @@ func (whisper *Whisper) SetBloomFilter(bloom []byte) error {
 	whisper.settings.Store(bloomFilterIdx, b)
 	whisper.notifyPeersAboutBloomFilterChange(b)
 
+	whisper.wg.Add(1)
 	go func() {
 		// allow some time before all the peers have processed the notification
+		defer whisper.wg.Done()
 		time.Sleep(time.Duration(whisper.syncAllowance) * time.Second)
 		whisper.settings.Store(bloomFilterToleranceIdx, b)
 	}()
@@ -261,7 +265,9 @@ func (whisper *Whisper) SetMinimumPoW(val float64) error {
 	whisper.settings.Store(minPowIdx, val)
 	whisper.notifyPeersAboutPowRequirementChange(val)
 
+	whisper.wg.Add(1)
 	go func() {
+		defer whisper.wg.Done()
 		// allow some time before all the peers have processed the notification
 		time.Sleep(time.Duration(whisper.syncAllowance) * time.Second)
 		whisper.settings.Store(minPowToleranceIdx, val)
@@ -626,10 +632,12 @@ func (whisper *Whisper) Send(envelope *Envelope) error {
 // of the Whisper protocol.
 func (whisper *Whisper) Start(*p2p.Server) error {
 	log.Info("started whisper v." + ProtocolVersionStr)
+	whisper.wg.Add(1)
 	go whisper.update()
 
 	numCPU := runtime.NumCPU()
 	for i := 0; i < numCPU; i++ {
+		whisper.wg.Add(1)
 		go whisper.processQueue()
 	}
 
@@ -640,6 +648,7 @@ func (whisper *Whisper) Start(*p2p.Server) error {
 // of the Whisper protocol.
 func (whisper *Whisper) Stop() error {
 	close(whisper.quit)
+	whisper.wg.Wait()
 	log.Info("whisper stopped")
 	return nil
 }
@@ -874,6 +883,7 @@ func (whisper *Whisper) checkOverflow() {
 
 // processQueue delivers the messages to the watchers during the lifetime of the whisper node.
 func (whisper *Whisper) processQueue() {
+	defer whisper.wg.Done()
 	var e *Envelope
 	for {
 		select {
@@ -892,6 +902,7 @@ func (whisper *Whisper) processQueue() {
 // update loops until the lifetime of the whisper node, updating its internal
 // state by expiring stale messages from the pool.
 func (whisper *Whisper) update() {
+	defer whisper.wg.Done()
 	// Start a ticker to check for expirations
 	expire := time.NewTicker(expirationCycle)
 
