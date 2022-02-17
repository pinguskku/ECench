commit 319098cc1c5ae6f54a8f05d77c564ff31c828814
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Jul 2 12:19:41 2018 +0300

    trie: fix a temporary memory leak in the memcache

diff --git a/trie/database.go b/trie/database.go
index 88c6e9cd6..df7fc01ea 100644
--- a/trie/database.go
+++ b/trie/database.go
@@ -466,7 +466,13 @@ func (db *Database) dereference(child common.Hash, parent common.Hash) {
 		return
 	}
 	// If there are no more references to the child, delete it and cascade
-	node.parents--
+	if node.parents > 0 {
+		// This is a special cornercase where a node loaded from disk (i.e. not in the
+		// memcache any more) gets reinjected as a new node (short node split into full,
+		// then reverted into short), causing a cached node to have no parents. That is
+		// no problem in itself, but don't make maxint parents out of it.
+		node.parents--
+	}
 	if node.parents == 0 {
 		// Remove the node from the flush-list
 		if child == db.oldest {
@@ -717,3 +723,45 @@ func (db *Database) Size() (common.StorageSize, common.StorageSize) {
 	var flushlistSize = common.StorageSize((len(db.nodes) - 1) * 2 * common.HashLength)
 	return db.nodesSize + flushlistSize, db.preimagesSize
 }
+
+// verifyIntegrity is a debug method to iterate over the entire trie stored in
+// memory and check whether every node is reachable from the meta root. The goal
+// is to find any errors that might cause memory leaks and or trie nodes to go
+// missing.
+//
+// This method is extremely CPU and memory intensive, only use when must.
+func (db *Database) verifyIntegrity() {
+	// Iterate over all the cached nodes and accumulate them into a set
+	reachable := map[common.Hash]struct{}{{}: {}}
+
+	for child := range db.nodes[common.Hash{}].children {
+		db.accumulate(child, reachable)
+	}
+	// Find any unreachable but cached nodes
+	unreachable := []string{}
+	for hash, node := range db.nodes {
+		if _, ok := reachable[hash]; !ok {
+			unreachable = append(unreachable, fmt.Sprintf("%x: {Node: %v, Parents: %d, Prev: %x, Next: %x}",
+				hash, node.node, node.parents, node.flushPrev, node.flushNext))
+		}
+	}
+	if len(unreachable) != 0 {
+		panic(fmt.Sprintf("trie cache memory leak: %v", unreachable))
+	}
+}
+
+// accumulate iterates over the trie defined by hash and accumulates all the
+// cached children found in memory.
+func (db *Database) accumulate(hash common.Hash, reachable map[common.Hash]struct{}) {
+	// Mark the node reachable if present in the memory cache
+	node, ok := db.nodes[hash]
+	if !ok {
+		return
+	}
+	reachable[hash] = struct{}{}
+
+	// Iterate over all the children and accumulate them too
+	for _, child := range node.childs() {
+		db.accumulate(child, reachable)
+	}
+}
