commit 3e68d627b1b930a824942204ae3cd0b042cd1dbb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 10:19:28 2021 +0200

    les: fix goroutine leaks in tests (#22707)

diff --git a/les/server.go b/les/server.go
index d44b1b57d..c135e65f2 100644
--- a/les/server.go
+++ b/les/server.go
@@ -212,17 +212,25 @@ func (s *LesServer) Stop() error {
 	close(s.closeCh)
 
 	s.clientPool.Stop()
-	s.serverset.close()
+	if s.serverset != nil {
+		s.serverset.close()
+	}
 	s.peers.close()
 	s.fcManager.Stop()
 	s.costTracker.stop()
 	s.handler.stop()
 	s.servingQueue.stop()
-	s.vfluxServer.Stop()
+	if s.vfluxServer != nil {
+		s.vfluxServer.Stop()
+	}
 
 	// Note, bloom trie indexer is closed by parent bloombits indexer.
-	s.chtIndexer.Close()
-	s.lesDb.Close()
+	if s.chtIndexer != nil {
+		s.chtIndexer.Close()
+	}
+	if s.lesDb != nil {
+		s.lesDb.Close()
+	}
 	s.wg.Wait()
 	log.Info("Les server stopped")
 
diff --git a/les/test_helper.go b/les/test_helper.go
index ee2da2f8e..fc85ed957 100644
--- a/les/test_helper.go
+++ b/les/test_helper.go
@@ -189,7 +189,7 @@ func testIndexers(db ethdb.Database, odr light.OdrBackend, config *light.Indexer
 	return indexers[:]
 }
 
-func newTestClientHandler(backend *backends.SimulatedBackend, odr *LesOdr, indexers []*core.ChainIndexer, db ethdb.Database, peers *serverPeerSet, ulcServers []string, ulcFraction int) *clientHandler {
+func newTestClientHandler(backend *backends.SimulatedBackend, odr *LesOdr, indexers []*core.ChainIndexer, db ethdb.Database, peers *serverPeerSet, ulcServers []string, ulcFraction int) (*clientHandler, func()) {
 	var (
 		evmux  = new(event.TypeMux)
 		engine = ethash.NewFaker()
@@ -245,10 +245,12 @@ func newTestClientHandler(backend *backends.SimulatedBackend, odr *LesOdr, index
 		client.oracle.Start(backend)
 	}
 	client.handler.start()
-	return client.handler
+	return client.handler, func() {
+		client.handler.stop()
+	}
 }
 
-func newTestServerHandler(blocks int, indexers []*core.ChainIndexer, db ethdb.Database, clock mclock.Clock) (*serverHandler, *backends.SimulatedBackend) {
+func newTestServerHandler(blocks int, indexers []*core.ChainIndexer, db ethdb.Database, clock mclock.Clock) (*serverHandler, *backends.SimulatedBackend, func()) {
 	var (
 		gspec = core.Genesis{
 			Config:   params.AllEthashProtocolChanges,
@@ -314,7 +316,8 @@ func newTestServerHandler(blocks int, indexers []*core.ChainIndexer, db ethdb.Da
 	}
 	server.servingQueue.setThreads(4)
 	server.handler.start()
-	return server.handler, simulation
+	closer := func() { server.Stop() }
+	return server.handler, simulation, closer
 }
 
 func alwaysTrueFn() bool {
@@ -600,8 +603,8 @@ func newClientServerEnv(t *testing.T, config testnetConfig) (*testServer, *testC
 	ccIndexer, cbIndexer, cbtIndexer := cIndexers[0], cIndexers[1], cIndexers[2]
 	odr.SetIndexers(ccIndexer, cbIndexer, cbtIndexer)
 
-	server, b := newTestServerHandler(config.blocks, sindexers, sdb, clock)
-	client := newTestClientHandler(b, odr, cIndexers, cdb, speers, config.ulcServers, config.ulcFraction)
+	server, b, serverClose := newTestServerHandler(config.blocks, sindexers, sdb, clock)
+	client, clientClose := newTestClientHandler(b, odr, cIndexers, cdb, speers, config.ulcServers, config.ulcFraction)
 
 	scIndexer.Start(server.blockchain)
 	sbIndexer.Start(server.blockchain)
@@ -658,7 +661,10 @@ func newClientServerEnv(t *testing.T, config testnetConfig) (*testServer, *testC
 		cbIndexer.Close()
 		scIndexer.Close()
 		sbIndexer.Close()
+		dist.close()
+		serverClose()
 		b.Close()
+		clientClose()
 	}
 	return s, c, teardown
 }
