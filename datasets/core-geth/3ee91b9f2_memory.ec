commit 3ee91b9f2e400eee382f0f1a26b6fe233c4c3f9c
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Mon Aug 24 13:22:36 2020 +0300

    core/state/snapshot: reduce disk layer depth during generation

diff --git a/core/state/snapshot/generate.go b/core/state/snapshot/generate.go
index c3a4a552f..cf9b2b039 100644
--- a/core/state/snapshot/generate.go
+++ b/core/state/snapshot/generate.go
@@ -54,9 +54,11 @@ type generatorStats struct {
 
 // Log creates an contextual log with the given message and the context pulled
 // from the internally maintained statistics.
-func (gs *generatorStats) Log(msg string, marker []byte) {
+func (gs *generatorStats) Log(msg string, root common.Hash, marker []byte) {
 	var ctx []interface{}
-
+	if root != (common.Hash{}) {
+		ctx = append(ctx, []interface{}{"root", root}...)
+	}
 	// Figure out whether we're after or within an account
 	switch len(marker) {
 	case common.HashLength:
@@ -120,7 +122,7 @@ func generateSnapshot(diskdb ethdb.KeyValueStore, triedb *trie.Database, cache i
 func (dl *diskLayer) generate(stats *generatorStats) {
 	// If a database wipe is in operation, wait until it's done
 	if stats.wiping != nil {
-		stats.Log("Wiper running, state snapshotting paused", dl.genMarker)
+		stats.Log("Wiper running, state snapshotting paused", common.Hash{}, dl.genMarker)
 		select {
 		// If wiper is done, resume normal mode of operation
 		case <-stats.wiping:
@@ -137,13 +139,13 @@ func (dl *diskLayer) generate(stats *generatorStats) {
 	accTrie, err := trie.NewSecure(dl.root, dl.triedb)
 	if err != nil {
 		// The account trie is missing (GC), surf the chain until one becomes available
-		stats.Log("Trie missing, state snapshotting paused", dl.genMarker)
+		stats.Log("Trie missing, state snapshotting paused", dl.root, dl.genMarker)
 
 		abort := <-dl.genAbort
 		abort <- stats
 		return
 	}
-	stats.Log("Resuming state snapshot generation", dl.genMarker)
+	stats.Log("Resuming state snapshot generation", dl.root, dl.genMarker)
 
 	var accMarker []byte
 	if len(dl.genMarker) > 0 { // []byte{} is the start, use nil for that
@@ -192,7 +194,7 @@ func (dl *diskLayer) generate(stats *generatorStats) {
 				dl.lock.Unlock()
 			}
 			if abort != nil {
-				stats.Log("Aborting state snapshot generation", accountHash[:])
+				stats.Log("Aborting state snapshot generation", dl.root, accountHash[:])
 				abort <- stats
 				return
 			}
@@ -230,7 +232,7 @@ func (dl *diskLayer) generate(stats *generatorStats) {
 						dl.lock.Unlock()
 					}
 					if abort != nil {
-						stats.Log("Aborting state snapshot generation", append(accountHash[:], storeIt.Key...))
+						stats.Log("Aborting state snapshot generation", dl.root, append(accountHash[:], storeIt.Key...))
 						abort <- stats
 						return
 					}
@@ -238,7 +240,7 @@ func (dl *diskLayer) generate(stats *generatorStats) {
 			}
 		}
 		if time.Since(logged) > 8*time.Second {
-			stats.Log("Generating state snapshot", accIt.Key)
+			stats.Log("Generating state snapshot", dl.root, accIt.Key)
 			logged = time.Now()
 		}
 		// Some account processed, unmark the marker
diff --git a/core/state/snapshot/journal.go b/core/state/snapshot/journal.go
index 0e7345416..fc1053f81 100644
--- a/core/state/snapshot/journal.go
+++ b/core/state/snapshot/journal.go
@@ -193,7 +193,7 @@ func (dl *diskLayer) Journal(buffer *bytes.Buffer) (common.Hash, error) {
 		dl.genAbort <- abort
 
 		if stats = <-abort; stats != nil {
-			stats.Log("Journalling in-progress snapshot", dl.genMarker)
+			stats.Log("Journalling in-progress snapshot", dl.root, dl.genMarker)
 		}
 	}
 	// Ensure the layer didn't get stale
diff --git a/core/state/snapshot/snapshot.go b/core/state/snapshot/snapshot.go
index 8ea56d731..f6c5a6a9a 100644
--- a/core/state/snapshot/snapshot.go
+++ b/core/state/snapshot/snapshot.go
@@ -263,6 +263,13 @@ func (t *Tree) Cap(root common.Hash, layers int) error {
 	if !ok {
 		return fmt.Errorf("snapshot [%#x] is disk layer", root)
 	}
+	// If the generator is still running, use a more aggressive cap
+	diff.origin.lock.RLock()
+	if diff.origin.genMarker != nil && layers > 8 {
+		layers = 8
+	}
+	diff.origin.lock.RUnlock()
+
 	// Run the internal capping and discard all stale layers
 	t.lock.Lock()
 	defer t.lock.Unlock()
