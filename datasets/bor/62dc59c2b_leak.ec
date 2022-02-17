commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
commit 62dc59c2bd6c80b711e873300d7cb91afa91e830
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index 7645f04e4..5e46042ae 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -569,7 +569,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 		<-proceed
 	}
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d5813c18a..5f07affdc 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -347,7 +347,11 @@ func (w *worker) newWorkLoop(recommit time.Duration) {
 			atomic.StoreInt32(interrupt, s)
 		}
 		interrupt = new(int32)
-		w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: interrupt, noempty: noempty, timestamp: timestamp}:
+		case <-w.exitCh:
+			return
+		}
 		timer.Reset(recommit)
 		atomic.StoreInt32(&w.newTxs, 0)
 	}
