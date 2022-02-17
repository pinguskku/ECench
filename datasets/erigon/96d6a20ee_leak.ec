commit 96d6a20ee47838f09b7dfe02c960a44e10df0db0
Author: Boqin Qin <Bobbqqin@gmail.com>
Date:   Tue Feb 18 00:33:12 2020 +0800

    all: fix goroutine leaks in unit tests by adding 1-elem channel buffer (#20666)
    
    This fixes a bunch of cases where a timeout in the test would leak
    a goroutine.

diff --git a/common/mclock/simclock_test.go b/common/mclock/simclock_test.go
index 94aa4f2b3..48f3fd56a 100644
--- a/common/mclock/simclock_test.go
+++ b/common/mclock/simclock_test.go
@@ -96,7 +96,7 @@ func TestSimulatedSleep(t *testing.T) {
 	var (
 		c       Simulated
 		timeout = 1 * time.Hour
-		done    = make(chan AbsTime)
+		done    = make(chan AbsTime, 1)
 	)
 	go func() {
 		c.Sleep(timeout)
diff --git a/eth/handler_test.go b/eth/handler_test.go
index 9ae8a1905..42a8700a4 100644
--- a/eth/handler_test.go
+++ b/eth/handler_test.go
@@ -1320,7 +1320,7 @@ func TestBroadcastMalformedBlock(t *testing.T) {
 	malformedEverything.TxHash[0]++
 
 	// Keep listening to broadcasts and notify if any arrives
-	notify := make(chan struct{})
+	notify := make(chan struct{}, 1)
 	go func() {
 		if _, err := sink.app.ReadMsg(); err == nil {
 			notify <- struct{}{}
diff --git a/p2p/server_test.go b/p2p/server_test.go
index 34371beb1..ccd6a89ee 100644
--- a/p2p/server_test.go
+++ b/p2p/server_test.go
@@ -550,7 +550,7 @@ func TestServerInboundThrottle(t *testing.T) {
 	conn.Close()
 
 	// Dial again. This time the server should close the connection immediately.
-	connClosed := make(chan struct{})
+	connClosed := make(chan struct{}, 1)
 	conn, err = net.DialTimeout("tcp", srv.ListenAddr, timeout)
 	if err != nil {
 		t.Fatalf("could not dial: %v", err)
diff --git a/rpc/client_test.go b/rpc/client_test.go
index 97f9a95b2..a89f25704 100644
--- a/rpc/client_test.go
+++ b/rpc/client_test.go
@@ -297,7 +297,7 @@ func TestClientSubscribeClose(t *testing.T) {
 
 	var (
 		nc   = make(chan int)
-		errc = make(chan error)
+		errc = make(chan error, 1)
 		sub  *ClientSubscription
 		err  error
 	)
