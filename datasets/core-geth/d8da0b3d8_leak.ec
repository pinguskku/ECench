commit d8da0b3d81d6623e0e500de11f50c2858e1fb9e7
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Aug 26 13:05:06 2020 +0300

    core/state, eth, trie: stabilize memory use, fix memory leak

diff --git a/core/state/statedb.go b/core/state/statedb.go
index cd020e654..36f7d863a 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -847,7 +847,7 @@ func (s *StateDB) Commit(deleteEmptyObjects bool) (common.Hash, error) {
 	// The onleaf func is called _serially_, so we can reuse the same account
 	// for unmarshalling every time.
 	var account Account
-	root, err := s.trie.Commit(func(leaf []byte, parent common.Hash) error {
+	root, err := s.trie.Commit(func(path []byte, leaf []byte, parent common.Hash) error {
 		if err := rlp.DecodeBytes(leaf, &account); err != nil {
 			return nil
 		}
diff --git a/core/state/sync.go b/core/state/sync.go
index 052cfad7b..1018b78e5 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -28,13 +28,13 @@ import (
 // NewStateSync create a new state trie download scheduler.
 func NewStateSync(root common.Hash, database ethdb.KeyValueReader, bloom *trie.SyncBloom) *trie.Sync {
 	var syncer *trie.Sync
-	callback := func(leaf []byte, parent common.Hash) error {
+	callback := func(path []byte, leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
 			return err
 		}
-		syncer.AddSubTrie(obj.Root, 64, parent, nil)
-		syncer.AddCodeEntry(common.BytesToHash(obj.CodeHash), 64, parent)
+		syncer.AddSubTrie(obj.Root, path, parent, nil)
+		syncer.AddCodeEntry(common.BytesToHash(obj.CodeHash), path, parent)
 		return nil
 	}
 	syncer = trie.NewSync(root, database, callback, bloom)
diff --git a/eth/downloader/downloader.go b/eth/downloader/downloader.go
index 4c5b270b7..f5bdb3c23 100644
--- a/eth/downloader/downloader.go
+++ b/eth/downloader/downloader.go
@@ -1611,7 +1611,13 @@ func (d *Downloader) processFastSyncContent(latest *types.Header) error {
 	// Start syncing state of the reported head block. This should get us most of
 	// the state of the pivot block.
 	sync := d.syncState(latest.Root)
-	defer sync.Cancel()
+	defer func() {
+		// The `sync` object is replaced every time the pivot moves. We need to
+		// defer close the very last active one, hence the lazy evaluation vs.
+		// calling defer sync.Cancel() !!!
+		sync.Cancel()
+	}()
+
 	closeOnErr := func(s *stateSync) {
 		if err := s.Wait(); err != nil && err != errCancelStateFetch && err != errCanceled {
 			d.queue.Close() // wake up Results
@@ -1674,9 +1680,8 @@ func (d *Downloader) processFastSyncContent(latest *types.Header) error {
 			// If new pivot block found, cancel old state retrieval and restart
 			if oldPivot != P {
 				sync.Cancel()
-
 				sync = d.syncState(P.Header.Root)
-				defer sync.Cancel()
+
 				go closeOnErr(sync)
 				oldPivot = P
 			}
diff --git a/trie/committer.go b/trie/committer.go
index 2f3d2a463..fc8b7ceda 100644
--- a/trie/committer.go
+++ b/trie/committer.go
@@ -226,12 +226,12 @@ func (c *committer) commitLoop(db *Database) {
 			switch n := n.(type) {
 			case *shortNode:
 				if child, ok := n.Val.(valueNode); ok {
-					c.onleaf(child, hash)
+					c.onleaf(nil, child, hash)
 				}
 			case *fullNode:
 				for i := 0; i < 16; i++ {
 					if child, ok := n.Children[i].(valueNode); ok {
-						c.onleaf(child, hash)
+						c.onleaf(nil, child, hash)
 					}
 				}
 			}
diff --git a/trie/sync.go b/trie/sync.go
index af9946641..147307fe7 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -34,14 +34,19 @@ var ErrNotRequested = errors.New("not requested")
 // node it already processed previously.
 var ErrAlreadyProcessed = errors.New("already processed")
 
+// maxFetchesPerDepth is the maximum number of pending trie nodes per depth. The
+// role of this value is to limit the number of trie nodes that get expanded in
+// memory if the node was configured with a significant number of peers.
+const maxFetchesPerDepth = 16384
+
 // request represents a scheduled or already in-flight state retrieval request.
 type request struct {
+	path []byte      // Merkle path leading to this node for prioritization
 	hash common.Hash // Hash of the node data content to retrieve
 	data []byte      // Data content of the node, cached until all subtrees complete
 	code bool        // Whether this is a code entry
 
 	parents []*request // Parent state nodes referencing this entry (notify all upon completion)
-	depth   int        // Depth level within the trie the node is located to prioritise DFS
