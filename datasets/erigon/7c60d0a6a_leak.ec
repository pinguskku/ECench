commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
commit 7c60d0a6a2d3925c2862cbbb188988475619fd0d
Author: lash <nolash@users.noreply.github.com>
Date:   Tue Feb 5 14:35:20 2019 +0100

    swarm/pss: Remove pss service leak in test (#18992)

diff --git a/swarm/pss/forwarding_test.go b/swarm/pss/forwarding_test.go
index 084688439..250297794 100644
--- a/swarm/pss/forwarding_test.go
+++ b/swarm/pss/forwarding_test.go
@@ -54,6 +54,7 @@ func TestForwardBasic(t *testing.T) {
 
 	kad := network.NewKademlia(base[:], network.NewKadParams())
 	ps := createPss(t, kad)
+	defer ps.Stop()
 	addPeers(kad, peerAddresses)
 
 	const firstNearest = depth * 2 // shallowest peer in the nearest neighbours' bin
diff --git a/swarm/pss/pss_test.go b/swarm/pss/pss_test.go
index 46daa4674..0fb87be2c 100644
--- a/swarm/pss/pss_test.go
+++ b/swarm/pss/pss_test.go
@@ -170,6 +170,7 @@ func TestCache(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	pp := NewPssParams().WithPrivateKey(privkey)
 	data := []byte("foo")
 	datatwo := []byte("bar")
@@ -648,6 +649,7 @@ func TestMessageProcessing(t *testing.T) {
 	addr := make([]byte, 32)
 	addr[0] = 0x01
 	ps := newTestPss(privkey, network.NewKademlia(addr, network.NewKadParams()), NewPssParams())
+	defer ps.Stop()
 
 	// message should pass
 	msg := newPssMsg(&msgParams{})
@@ -780,6 +782,7 @@ func TestKeys(t *testing.T) {
 		t.Fatalf("failed to retrieve 'their' private key")
 	}
 	ps := newTestPss(ourprivkey, nil, nil)
+	defer ps.Stop()
 
 	// set up peer with mock address, mapped to mocked publicaddress and with mocked symkey
 	addr := make(PssAddress, 32)
@@ -829,6 +832,7 @@ func TestGetPublickeyEntries(t *testing.T) {
 		t.Fatal(err)
 	}
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 
 	peeraddr := network.RandomAddr().Over()
 	topicaddr := make(map[Topic]PssAddress)
@@ -932,6 +936,7 @@ func TestPeerCapabilityMismatch(t *testing.T) {
 		Payload: &whisper.Envelope{},
 	}
 	ps := newTestPss(privkey, kad, nil)
+	defer ps.Stop()
 
 	// run the forward
 	// it is enough that it completes; trying to send to incapable peers would create segfault
@@ -950,6 +955,7 @@ func TestRawAllow(t *testing.T) {
 	baseAddr := network.RandomAddr()
 	kad := network.NewKademlia((baseAddr).Over(), network.NewKadParams())
 	ps := newTestPss(privKey, kad, nil)
+	defer ps.Stop()
 	topic := BytesToTopic([]byte{0x2a})
 
 	// create handler innards that increments every time a message hits it
@@ -1691,6 +1697,7 @@ func benchmarkSymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1735,6 +1742,7 @@ func benchmarkAsymKeySend(b *testing.B) {
 	keys, err := wapi.NewKeyPair(ctx)
 	privkey, err := w.GetPrivateKey(keys)
 	ps := newTestPss(privkey, nil, nil)
+	defer ps.Stop()
 	msg := make([]byte, msgsize)
 	rand.Read(msg)
 	topic := BytesToTopic([]byte("foo"))
@@ -1785,6 +1793,7 @@ func benchmarkSymkeyBruteforceChangeaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		to := make(PssAddress, 32)
@@ -1868,6 +1877,7 @@ func benchmarkSymkeyBruteforceSameaddr(b *testing.B) {
 	} else {
 		ps = newTestPss(privkey, nil, nil)
 	}
+	defer ps.Stop()
 	topic := BytesToTopic([]byte("foo"))
 	for i := 0; i < int(keycount); i++ {
 		copy(addr[i], network.RandomAddr().Over())
