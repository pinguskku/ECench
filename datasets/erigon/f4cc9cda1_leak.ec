commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
commit f4cc9cda14efc34ce88030ac13b97d1449d00301
Author: Boqin Qin <bobbqqin@bupt.edu.cn>
Date:   Wed Feb 12 22:19:47 2020 +0800

    event, p2p/simulations/adapters: fix rare goroutine leaks (#20657)
    
    Co-authored-by: Felix Lange <fjl@twurst.com>

diff --git a/event/subscription.go b/event/subscription.go
index 0586cfa7c..c0d81ea7e 100644
--- a/event/subscription.go
+++ b/event/subscription.go
@@ -145,7 +145,6 @@ func (s *resubscribeSub) loop() {
 func (s *resubscribeSub) subscribe() Subscription {
 	subscribed := make(chan error)
 	var sub Subscription
-retry:
 	for {
 		s.lastTry = mclock.Now()
 		ctx, cancel := context.WithCancel(context.Background())
@@ -157,19 +156,19 @@ retry:
 		select {
 		case err := <-subscribed:
 			cancel()
-			if err != nil {
-				// Subscribing failed, wait before launching the next try.
-				if s.backoffWait() {
-					return nil
+			if err == nil {
+				if sub == nil {
+					panic("event: ResubscribeFunc returned nil subscription and no error")
 				}
-				continue retry
+				return sub
 			}
-			if sub == nil {
-				panic("event: ResubscribeFunc returned nil subscription and no error")
+			// Subscribing failed, wait before launching the next try.
+			if s.backoffWait() {
+				return nil // unsubscribed during wait
 			}
-			return sub
 		case <-s.unsub:
 			cancel()
+			<-subscribed // avoid leaking the s.fn goroutine.
 			return nil
 		}
 	}
diff --git a/event/subscription_test.go b/event/subscription_test.go
index 5b8a2c8ed..c48be3aa3 100644
--- a/event/subscription_test.go
+++ b/event/subscription_test.go
@@ -102,7 +102,7 @@ func TestResubscribe(t *testing.T) {
 func TestResubscribeAbort(t *testing.T) {
 	t.Parallel()
 
-	done := make(chan error)
+	done := make(chan error, 1)
 	sub := Resubscribe(0, func(ctx context.Context) (Subscription, error) {
 		select {
 		case <-ctx.Done():
diff --git a/p2p/simulations/adapters/exec.go b/p2p/simulations/adapters/exec.go
index 34c978646..980f85840 100644
--- a/p2p/simulations/adapters/exec.go
+++ b/p2p/simulations/adapters/exec.go
@@ -289,7 +289,7 @@ func (n *ExecNode) Stop() error {
 	if err := n.Cmd.Process.Signal(syscall.SIGTERM); err != nil {
 		return n.Cmd.Process.Kill()
 	}
-	waitErr := make(chan error)
+	waitErr := make(chan error, 1)
 	go func() {
 		waitErr <- n.Cmd.Wait()
 	}()
