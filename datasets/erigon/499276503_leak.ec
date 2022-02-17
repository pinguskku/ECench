commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
commit 4992765032b4318f3f5b4940a553b4e552c55963
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Tue Apr 28 10:28:04 2015 +0300

    p2p/discover: fix goroutine leak due to blocking on sync.Once

diff --git a/p2p/discover/database.go b/p2p/discover/database.go
index 48539a6c9..d966a6ac1 100644
--- a/p2p/discover/database.go
+++ b/p2p/discover/database.go
@@ -177,23 +177,34 @@ func (db *nodeDB) updateNode(node *Node) error {
 	return db.lvl.Put(makeKey(node.ID, nodeDBDiscoverRoot), blob, nil)
 }
 
+// ensureExpirer is a small helper method ensuring that the data expiration
+// mechanism is running. If the expiration goroutine is already running, this
+// method simply returns.
+//
+// The goal is to start the data evacuation only after the network successfully
+// bootstrapped itself (to prevent dumping potentially useful seed nodes). Since
+// it would require significant overhead to exactly trace the first successful
+// convergence, it's simpler to "ensure" the correct state when an appropriate
+// condition occurs (i.e. a successful bonding), and discard further events.
+func (db *nodeDB) ensureExpirer() {
+	db.runner.Do(func() { go db.expirer() })
+}
+
 // expirer should be started in a go routine, and is responsible for looping ad
 // infinitum and dropping stale data from the database.
 func (db *nodeDB) expirer() {
-	db.runner.Do(func() {
-		tick := time.Tick(nodeDBCleanupCycle)
-		for {
-			select {
-			case <-tick:
-				if err := db.expireNodes(); err != nil {
-					glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
-				}
-
-			case <-db.quit:
-				return
+	tick := time.Tick(nodeDBCleanupCycle)
+	for {
+		select {
+		case <-tick:
+			if err := db.expireNodes(); err != nil {
+				glog.V(logger.Error).Infof("Failed to expire nodedb items: %v", err)
 			}
+
+		case <-db.quit:
+			return
 		}
-	})
+	}
 }
 
 // expireNodes iterates over the database and deletes all nodes that have not
diff --git a/p2p/discover/table.go b/p2p/discover/table.go
index 060aa7c09..d3fe373f4 100644
--- a/p2p/discover/table.go
+++ b/p2p/discover/table.go
@@ -335,7 +335,7 @@ func (tab *Table) ping(id NodeID, addr *net.UDPAddr) error {
 	}
 	// Pong received, update the database and return
 	tab.db.updateLastPong(id, time.Now())
-	go tab.db.expirer()
+	tab.db.ensureExpirer()
 
 	return nil
 }
