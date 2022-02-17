commit 79a6782c1c4a056b27d2c242f656dfcf5633ae3f
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 17:06:19 2015 +0200

    p2p: fix goroutine leak when handshake read fails
    
    This regression was introduced in b3c058a9e4e9.

diff --git a/p2p/handshake.go b/p2p/handshake.go
index 43361364f..79395f23f 100644
--- a/p2p/handshake.go
+++ b/p2p/handshake.go
@@ -115,7 +115,7 @@ func setupOutboundConn(fd net.Conn, prv *ecdsa.PrivateKey, our *protoHandshake,
 	// returning the handshake read error. If the remote side
 	// disconnects us early with a valid reason, we should return it
 	// as the error so it can be tracked elsewhere.
-	werr := make(chan error)
+	werr := make(chan error, 1)
 	go func() { werr <- Send(rw, handshakeMsg, our) }()
 	rhs, err := readProtocolHandshake(rw, secrets.RemoteID, our)
 	if err != nil {
