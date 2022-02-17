commit bc47993692a446437b0d91cae758fb6be664050e
Author: Martin Holst Swende <martin@swende.se>
Date:   Tue Mar 16 09:43:33 2021 +0100

    tests/fuzzers: fix goroutine leak in les fuzzer (#22455)
    
    The oss-fuzz fuzzer has been reporting some failing testcases for les. They're all spurious, and cannot reliably be reproduced. However, running them showed that there was a goroutine leak: the tests created a lot of new clients, which started an exec queue that was never torn down.
    
    This PR fixes the goroutine leak, and also a log message which was erroneously formatted.

diff --git a/les/server_requests.go b/les/server_requests.go
index 07f30b1b7..bab5f733d 100644
--- a/les/server_requests.go
+++ b/les/server_requests.go
@@ -206,8 +206,8 @@ func handleGetBlockHeaders(msg Decoder) (serveRequestFn, uint64, uint64, error)
 					next    = current + r.Query.Skip + 1
 				)
 				if next <= current {
-					infos, _ := json.MarshalIndent(p.Peer.Info(), "", "  ")
-					p.Log().Warn("GetBlockHeaders skip overflow attack", "current", current, "skip", r.Query.Skip, "next", next, "attacker", infos)
+					infos, _ := json.Marshal(p.Peer.Info())
+					p.Log().Warn("GetBlockHeaders skip overflow attack", "current", current, "skip", r.Query.Skip, "next", next, "attacker", string(infos))
 					unknown = true
 				} else {
 					if header := bc.GetHeaderByNumber(next); header != nil {
diff --git a/les/test_helper.go b/les/test_helper.go
index 39313b1e3..e1d3beb6a 100644
--- a/les/test_helper.go
+++ b/les/test_helper.go
@@ -661,6 +661,10 @@ func newClientServerEnv(t *testing.T, config testnetConfig) (*testServer, *testC
 	return s, c, teardown
 }
 
-func NewFuzzerPeer(version int) *clientPeer {
-	return newClientPeer(version, 0, p2p.NewPeer(enode.ID{}, "", nil), nil)
+// NewFuzzerPeer creates a client peer for test purposes, and also returns
+// a function to close the peer: this is needed to avoid goroutine leaks in the
+// exec queue.
+func NewFuzzerPeer(version int) (p *clientPeer, closer func()) {
+	p = newClientPeer(version, 0, p2p.NewPeer(enode.ID{}, "", nil), nil)
+	return p, func() { p.peerCommons.close() }
 }
diff --git a/tests/fuzzers/les/les-fuzzer.go b/tests/fuzzers/les/les-fuzzer.go
index 9e896c2c1..3e1017187 100644
--- a/tests/fuzzers/les/les-fuzzer.go
+++ b/tests/fuzzers/les/les-fuzzer.go
@@ -261,18 +261,18 @@ func (d dummyMsg) Decode(val interface{}) error {
 }
 
 func (f *fuzzer) doFuzz(msgCode uint64, packet interface{}) {
-	version := f.randomInt(3) + 2 // [LES2, LES3, LES4]
-	peer := l.NewFuzzerPeer(version)
 	enc, err := rlp.EncodeToBytes(packet)
 	if err != nil {
 		panic(err)
 	}
+	version := f.randomInt(3) + 2 // [LES2, LES3, LES4]
+	peer, closeFn := l.NewFuzzerPeer(version)
+	defer closeFn()
 	fn, _, _, err := l.Les3[msgCode].Handle(dummyMsg{enc})
 	if err != nil {
 		panic(err)
 	}
 	fn(f, peer, func() bool { return true })
-
 }
 
 func Fuzz(input []byte) int {
