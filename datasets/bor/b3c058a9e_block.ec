commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
commit b3c058a9e4e9296583ba516c537768b96a2fb8a0
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Apr 10 13:25:35 2015 +0200

    p2p: improve disconnect signaling at handshake time
    
    As of this commit, p2p will disconnect nodes directly after the
    encryption handshake if too many peer connections are active.
    Errors in the protocol handshake packet are now handled more politely
    by sending a disconnect packet before closing the connection.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 5a259cd76..43361364f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -68,50 +68,61 @@ type protoHandshake struct {
 // setupConn starts a protocol session on the given connection.
 // It runs the encryption handshake and the protocol handshake.
 // If dial is non-nil, the connection the local node is the initiator.
-func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+// If atcap is true, the connection will be disconnected with DiscTooManyPeers
+// after the key exchange.
+func setupConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	if dial == nil {
-		return setupInboundConn(fd, prv, our)
+		return setupInboundConn(fd, prv, our, atcap)
 	} else {
-		return setupOutboundConn(fd, prv, our, dial)
+		return setupOutboundConn(fd, prv, our, dial, atcap)
 	}
 }
 
-func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake) (*conn, error) {
+func setupInboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, atcap bool) (*conn, error) {
 	secrets, err := receiverEncHandshake(fd, prv, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	rhs, err := readProtocolHandshake(rw, our)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
+	}
+	// Run the protocol handshake using authenticated messages.
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
 		return nil, err
 	}
-	if rhs.ID != secrets.RemoteID {
-		return nil, errors.New("node ID in protocol handshake does not match encryption handshake")
-	}
-	// TODO: validate that handshake node ID matches
 	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	return &conn{rw, rhs}, nil
 }
 
-func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 	secrets, err := initiatorEncHandshake(fd, prv, dial.ID, nil)
 	if err != nil {
 		return nil, fmt.Errorf("encryption handshake failed: %v", err)
 	}
-
-	// Run the protocol handshake using authenticated messages.
 	rw := newRlpxFrameRW(fd, secrets)
-	if err := Send(rw, handshakeMsg, our); err != nil {
-		return nil, fmt.Errorf("protocol write error: %v", err)
+	if atcap {
+		SendItems(rw, discMsg, DiscTooManyPeers)
+		return nil, errors.New("we have too many peers")
 	}
-	rhs, err := readProtocolHandshake(rw, our)
+	// Run the protocol handshake using authenticated messages.
+	//
+	// Note that even though writing the handshake is first, we prefer
+	// returning the handshake read error. If the remote side
+	// disconnects us early with a valid reason, we should return it
+	// as the error so it can be tracked elsewhere.
+	werr := make(chan error)
+	go func() { werr <- Send(rw, handshakeMsg, our) }()
+	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
-		return nil, fmt.Errorf("protocol handshake read error: %v", err)
+		return nil, err
+	}
+	if err := <-werr; err != nil {
+		return nil, fmt.Errorf("protocol handshake write error: %v", err)
 	}
 	if rhs.ID != dial.ID {
 		return nil, errors.New("dialed node id mismatch")
@@ -398,18 +409,17 @@ func xor(one, other []byte) (xor []byte) {
 	return xor
 }
 
-func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, error) {
-	// read and handle remote handshake
-	msg, err := r.ReadMsg()
+func readProtocolHandshake(rw MsgReadWriter, wantID discover.NodeID, our *protoHandshake) (*protoHandshake, error) {
+	msg, err := rw.ReadMsg()
 	if err != nil {
 		return nil, err
 	}
 	if msg.Code == discMsg {
 		// disconnect before protocol handshake is valid according to the
 		// spec and we send it ourself if Server.addPeer fails.
-		var reason DiscReason
+		var reason [1]DiscReason
 		rlp.Decode(msg.Payload, &reason)
-		return nil, reason
+		return nil, reason[0]
 	}
 	if msg.Code != handshakeMsg {
 		return nil, fmt.Errorf("expected handshake, got %x", msg.Code)
@@ -423,10 +433,16 @@ func readProtocolHandshake(r MsgReader, our *protoHandshake) (*protoHandshake, e
 	}
 	// validate handshake info
 	if hs.Version != our.Version {
-		return nil, newPeerError(errP2PVersionMismatch, "required version %d, received %d\n", baseProtocolVersion, hs.Version)
+		SendItems(rw, discMsg, DiscIncompatibleVersion)
+		return nil, fmt.Errorf("required version %d, received %d\n", baseProtocolVersion, hs.Version)
 	}
 	if (hs.ID == discover.NodeID{}) {
-		return nil, newPeerError(errPubkeyInvalid, "missing")
+		SendItems(rw, discMsg, DiscInvalidIdentity)
+		return nil, errors.New("invalid public key in handshake")
+	}
+	if hs.ID != wantID {
+		SendItems(rw, discMsg, DiscUnexpectedIdentity)
+		return nil, errors.New("handshake node ID does not match encryption handshake")
 	}
 	return &hs, nil
 }
diff --git a/p2p/handshake_test.go b/p2p/handshake_test.go
index 19423bb82..c22af7a9c 100644
--- a/p2p/handshake_test.go
+++ b/p2p/handshake_test.go
@@ -143,7 +143,7 @@ func TestSetupConn(t *testing.T) {
 	done := make(chan struct{})
 	go func() {
 		defer close(done)
-		conn0, err := setupConn(fd0, prv0, hs0, node1)
+		conn0, err := setupConn(fd0, prv0, hs0, node1, false)
 		if err != nil {
 			t.Errorf("outbound side error: %v", err)
 			return
@@ -156,7 +156,7 @@ func TestSetupConn(t *testing.T) {
 		}
 	}()
 
-	conn1, err := setupConn(fd1, prv1, hs1, nil)
+	conn1, err := setupConn(fd1, prv1, hs1, nil, false)
 	if err != nil {
 		t.Fatalf("inbound side error: %v", err)
 	}
diff --git a/p2p/server.go b/p2p/server.go
index d227d477a..88f7ba2ec 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -99,7 +99,7 @@ type Server struct {
 	peerConnect chan *discover.Node
 }
 
-type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node) (*conn, error)
+type setupFunc func(net.Conn, *ecdsa.PrivateKey, *protoHandshake, *discover.Node, bool) (*conn, error)
 type newPeerHook func(*Peer)
 
 // Peers returns all connected peers.
@@ -261,6 +261,11 @@ func (srv *Server) Stop() {
 	srv.peerWG.Wait()
 }
 
+// Self returns the local node's endpoint information.
+func (srv *Server) Self() *discover.Node {
+	return srv.ntab.Self()
+}
+
 // main loop for adding connections via listening
 func (srv *Server) listenLoop() {
 	defer srv.loopWG.Done()
@@ -354,10 +359,6 @@ func (srv *Server) dialNode(dest *discover.Node) {
 	srv.startPeer(conn, dest)
 }
 
-func (srv *Server) Self() *discover.Node {
-	return srv.ntab.Self()
-}
-
 func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// TODO: handle/store session token
 
@@ -366,7 +367,10 @@ func (srv *Server) startPeer(fd net.Conn, dest *discover.Node) {
 	// returns during that exchange need to call peerWG.Done because
 	// the callers of startPeer added the peer to the wait group already.
 	fd.SetDeadline(time.Now().Add(handshakeTimeout))
-	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest)
+	srv.lock.RLock()
+	atcap := len(srv.peers) == srv.MaxPeers
+	srv.lock.RUnlock()
+	conn, err := srv.setupFunc(fd, srv.PrivateKey, srv.ourHandshake, dest, atcap)
 	if err != nil {
 		fd.Close()
 		glog.V(logger.Debug).Infof("Handshake with %v failed: %v", fd.RemoteAddr(), err)
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 14e7c7de2..53cc3c258 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -22,7 +22,7 @@ func startTestServer(t *testing.T, pf newPeerHook) *Server {
 		ListenAddr:  "127.0.0.1:0",
 		PrivateKey:  newkey(),
 		newPeerHook: pf,
-		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node) (*conn, error) {
+		setupFunc: func(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake, dial *discover.Node, atcap bool) (*conn, error) {
 			id := randomID()
 			rw := newRlpxFrameRW(fd, secrets{
 				MAC:        zero16,
@@ -163,6 +163,62 @@ func TestServerBroadcast(t *testing.T) {
 	}
 }
 
+// This test checks that connections are disconnected
+// just after the encryption handshake when the server is
+// at capacity.
+//
+// It also serves as a light-weight integration test.
+func TestServerDisconnectAtCap(t *testing.T) {
+	defer testlog(t).detach()
+
+	started := make(chan *Peer)
+	srv := &Server{
+		ListenAddr: "127.0.0.1:0",
+		PrivateKey: newkey(),
+		MaxPeers:   10,
+		NoDial:     true,
+		// This hook signals that the peer was actually started. We
+		// need to wait for the peer to be started before dialing the
+		// next connection to get a deterministic peer count.
+		newPeerHook: func(p *Peer) { started <- p },
+	}
+	if err := srv.Start(); err != nil {
+		t.Fatal(err)
+	}
+	defer srv.Stop()
+
+	nconns := srv.MaxPeers + 1
+	dialer := &net.Dialer{Deadline: time.Now().Add(3 * time.Second)}
+	for i := 0; i < nconns; i++ {
+		conn, err := dialer.Dial("tcp", srv.ListenAddr)
+		if err != nil {
+			t.Fatalf("conn %d: dial error: %v", i, err)
+		}
+		// Close the connection when the test ends, before
+		// shutting down the server.
+		defer conn.Close()
+		// Run the handshakes just like a real peer would.
+		key := newkey()
+		hs := &protoHandshake{Version: baseProtocolVersion, ID: discover.PubkeyID(&key.PublicKey)}
+		_, err = setupConn(conn, key, hs, srv.Self(), false)
+		if i == nconns-1 {
+			// When handling the last connection, the server should
+			// disconnect immediately instead of running the protocol
+			// handshake.
+			if err != DiscTooManyPeers {
+				t.Errorf("conn %d: got error %q, expected %q", i, err, DiscTooManyPeers)
+			}
+		} else {
+			// For all earlier connections, the handshake should go through.
+			if err != nil {
+				t.Fatalf("conn %d: unexpected error: %v", i, err)
+			}
+			// Wait for runPeer to be started.
+			<-started
+		}
+	}
+}
+
 func newkey() *ecdsa.PrivateKey {
 	key, err := crypto.GenerateKey()
 	if err != nil {
