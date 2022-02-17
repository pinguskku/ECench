commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
commit 22ee366ed6419516eece4436c9f7b5b63ea8a713
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Feb 13 14:47:05 2015 +0100

    p2p: fix goroutine leak for invalid peers
    
    The deflect logic called Disconnect on the peer, but the peer never ran
    and wouldn't process the disconnect request.

diff --git a/p2p/server.go b/p2p/server.go
index e44f3d7ab..f61bb897e 100644
--- a/p2p/server.go
+++ b/p2p/server.go
@@ -351,19 +351,21 @@ func (srv *Server) startPeer(conn net.Conn, dest *discover.Node) {
 		srvlog.Debugf("Encryption Handshake with %v failed: %v", conn.RemoteAddr(), err)
 		return
 	}
-
 	ourID := srv.ntab.Self()
 	p := newPeer(conn, srv.Protocols, srv.Name, &ourID, &remoteID)
 	if ok, reason := srv.addPeer(remoteID, p); !ok {
-		p.Disconnect(reason)
+		srvlog.DebugDetailf("Not adding %v (%v)\n", p, reason)
+		p.politeDisconnect(reason)
 		return
 	}
+	srvlog.Debugf("Added %v\n", p)
 
 	if srv.newPeerHook != nil {
 		srv.newPeerHook(p)
 	}
-	p.run()
+	discreason := p.run()
 	srv.removePeer(p)
+	srvlog.Debugf("Removed %v (%v)\n", p, discreason)
 }
 
 func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
@@ -381,14 +383,11 @@ func (srv *Server) addPeer(id discover.NodeID, p *Peer) (bool, DiscReason) {
 	case id == srv.ntab.Self():
 		return false, DiscSelf
 	}
-	srvlog.Debugf("Adding %v\n", p)
 	srv.peers[id] = p
 	return true, 0
 }
 
-// removes peer: sending disconnect msg, stop peer, remove rom list/table, release slot
 func (srv *Server) removePeer(p *Peer) {
-	srvlog.Debugf("Removing %v\n", p)
 	srv.lock.Lock()
 	delete(srv.peers, *p.remoteID)
 	srv.lock.Unlock()
