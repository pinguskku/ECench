commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
commit a1cd7e6e92b5c48989c307b6051615c4502762ca
Author: Elad <theman@elad.im>
Date:   Fri Apr 26 16:29:28 2019 +0900

    p2p/protocols, swarm/network: fix resource leak with p2p teardown

diff --git a/p2p/protocols/protocol_test.go b/p2p/protocols/protocol_test.go
index 6d5ea8b92..00526b97a 100644
--- a/p2p/protocols/protocol_test.go
+++ b/p2p/protocols/protocol_test.go
@@ -269,6 +269,7 @@ func TestProtocolHook(t *testing.T) {
 		panic(err)
 	}
 	tester := p2ptest.NewProtocolTester(prvkey, 2, runFunc)
+	defer tester.Stop()
 	err = tester.TestExchanges(p2ptest.Exchange{
 		Expects: []p2ptest.Expect{
 			{
diff --git a/swarm/network/hive_test.go b/swarm/network/hive_test.go
index d03db42bc..3e9732216 100644
--- a/swarm/network/hive_test.go
+++ b/swarm/network/hive_test.go
@@ -117,7 +117,7 @@ func TestHiveStatePersistance(t *testing.T) {
 
 	const peersCount = 5
 
-	startHive := func(t *testing.T, dir string) (h *Hive) {
+	startHive := func(t *testing.T, dir string) (h *Hive, cleanupFunc func()) {
 		store, err := state.NewDBStore(dir)
 		if err != nil {
 			t.Fatal(err)
@@ -137,27 +137,30 @@ func TestHiveStatePersistance(t *testing.T) {
 		if err := h.Start(s.Server); err != nil {
 			t.Fatal(err)
 		}
-		return h
+
+		cleanupFunc = func() {
+			err := h.Stop()
+			if err != nil {
+				t.Fatal(err)
+			}
+
+			s.Stop()
+		}
+		return h, cleanupFunc
 	}
 
-	h1 := startHive(t, dir)
+	h1, cleanup1 := startHive(t, dir)
 	peers := make(map[string]bool)
 	for i := 0; i < peersCount; i++ {
 		raddr := RandomAddr()
 		h1.Register(raddr)
 		peers[raddr.String()] = true
 	}
-	if err = h1.Stop(); err != nil {
-		t.Fatal(err)
-	}
+	cleanup1()
 
 	// start the hive and check that we know of all expected peers
-	h2 := startHive(t, dir)
-	defer func() {
-		if err = h2.Stop(); err != nil {
-			t.Fatal(err)
-		}
-	}()
+	h2, cleanup2 := startHive(t, dir)
+	cleanup2()
 
 	i := 0
 	h2.Kademlia.EachAddr(nil, 256, func(addr *BzzAddr, po int) bool {
diff --git a/swarm/network/protocol_test.go b/swarm/network/protocol_test.go
index 2207ba308..737ad0784 100644
--- a/swarm/network/protocol_test.go
+++ b/swarm/network/protocol_test.go
@@ -235,6 +235,7 @@ func TestBzzHandshakeNetworkIDMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -258,6 +259,7 @@ func TestBzzHandshakeVersionMismatch(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -281,6 +283,7 @@ func TestBzzHandshakeSuccess(t *testing.T) {
 	if err != nil {
 		t.Fatal(err)
 	}
+	defer s.Stop()
 	node := s.Nodes[0]
 
 	err = s.testHandshake(
@@ -312,6 +315,7 @@ func TestBzzHandshakeLightNode(t *testing.T) {
 			if err != nil {
 				t.Fatal(err)
 			}
+			defer pt.Stop()
 
 			node := pt.Nodes[0]
 			addr := NewAddr(node)
diff --git a/swarm/network/stream/common_test.go b/swarm/network/stream/common_test.go
index 1b2812f4f..8e6be72b6 100644
--- a/swarm/network/stream/common_test.go
+++ b/swarm/network/stream/common_test.go
@@ -178,12 +178,7 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	netStore.NewNetFetcherFunc = network.NewFetcherFactory(delivery.RequestFromPeers, true).New
 	intervalsStore := state.NewInmemoryStore()
 	streamer := NewRegistry(addr.ID(), delivery, netStore, intervalsStore, registryOptions, nil)
-	teardown := func() {
-		streamer.Close()
-		intervalsStore.Close()
-		netStore.Close()
-		removeDataDir()
-	}
+
 	prvkey, err := crypto.GenerateKey()
 	if err != nil {
 		removeDataDir()
@@ -191,7 +186,13 @@ func newStreamerTester(registryOptions *RegistryOptions) (*p2ptest.ProtocolTeste
 	}
 
 	protocolTester := p2ptest.NewProtocolTester(prvkey, 1, streamer.runProtocol)
-
+	teardown := func() {
+		protocolTester.Stop()
+		streamer.Close()
+		intervalsStore.Close()
+		netStore.Close()
+		removeDataDir()
+	}
 	err = waitForPeers(streamer, 10*time.Second, 1)
 	if err != nil {
 		teardown()
