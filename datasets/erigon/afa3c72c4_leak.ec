commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
commit afa3c72c40eee45dfbf3cbc40505b78cb2c3c6b2
Author: ferhat elmas <elmas.ferhat@gmail.com>
Date:   Mon Dec 18 04:03:48 2017 +0100

    p2p/discover: fix leaked goroutine in data expiration

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 7206a63c6..b136609f2 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -226,14 +226,14 @@ func (db *nodeDB) ensureExpirer() {
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	tick := time.Tick(nodeDBCleanupCycle)
+	tick := time.NewTicker(nodeDBCleanupCycle)
+	defer tick.Stop()
 	for {
 		select {
-		case <-tick:
+		case <-tick.C:
 			if err := db.expireNodes(); err != nil {
 				log.Error("Failed to expire nodedb items", "err", err)
 			}
-
 		case <-db.quit:
 			return
 		}
