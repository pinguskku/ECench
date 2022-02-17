commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
commit 0217652d1b7e8f0c1c3002837d9f1277de27ef46
Author: Felix Lange <fjl@twurst.com>
Date:   Mon Apr 13 18:08:11 2015 +0200

    p2p/discover: improve timer handling for reply timeouts

diff --git a/p2p/discover/udp.go b/p2p/discover/udp.go
index d37260e7d..61a0abed9 100644
--- a/p2p/discover/udp.go
+++ b/p2p/discover/udp.go
@@ -267,11 +267,12 @@ func (t *udp) loop() {
 	defer timeout.Stop()
 
 	rearmTimeout := func() {
-		if len(pending) == 0 || nextDeadline == pending[0].deadline {
+		now := time.Now()
+		if len(pending) == 0 || now.Before(nextDeadline) {
 			return
 		}
 		nextDeadline = pending[0].deadline
-		timeout.Reset(nextDeadline.Sub(time.Now()))
+		timeout.Reset(nextDeadline.Sub(now))
 	}
 
 	for {
