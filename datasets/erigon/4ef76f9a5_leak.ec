commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
commit 4ef76f9a58ce497c491067675703f21494b411b0
Author: lzhfromustc <43191155+lzhfromustc@users.noreply.github.com>
Date:   Fri Dec 11 04:29:42 2020 -0500

    miner, test: fix potential goroutine leak (#21989)
    
    In miner/worker.go, there are two goroutine using channel w.newWorkCh: newWorkerLoop() sends to this channel, and mainLoop() receives from this channel. Only the receive operation is in a select.
    
    However, w.exitCh may be closed by another goroutine. This is fine for the receive since receive is in select, but if the send operation is blocking, then it will block forever. This commit puts the send in a select, so it won't block even if w.exitCh is closed.
    
    Similarly, there are two goroutines using channel errc: the parent that runs the test receives from it, and the child created at line 573 sends to it. If the parent goroutine exits too early by calling t.Fatalf() at line 614, then the child goroutine will be blocked at line 574 forever. This commit adds 1 buffer to errc. Now send will not block, and receive is not influenced because receive still needs to wait for the send.
    # Conflicts:
    #       miner/worker.go

diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index fc6e62742..476d5b8f3 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -582,7 +582,7 @@ func testThrottling(t *testing.T, protocol int, mode SyncMode) {
 	}
 
 	// Start a synchronisation concurrently
-	errc := make(chan error)
+	errc := make(chan error, 1)
 	go func() {
 		errc <- tester.sync("peer", nil, mode)
 	}()
diff --git a/miner/worker.go b/miner/worker.go
index d6780bfbb..b3820f9a0 100644
--- a/miner/worker.go
+++ b/miner/worker.go
@@ -402,7 +402,12 @@ func (w *worker) getCommit() (func(ctx consensus.Cancel, noempty bool, s int32),
 
 		v := interrupt.Load().(*int32)
 
-		w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}
+		select {
+		case w.newWorkCh <- &newWorkReq{interrupt: v, noempty: noempty, timestamp: atomic.LoadInt64(timestamp), cancel: consensus.NewCancel()}:
+		case <-w.exitCh:
+			return
+		}
+
 		atomic.StoreInt32(&w.newTxs, 0)
 	}, timestamp
 }
