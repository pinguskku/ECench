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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
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
 	deps    int        // Number of dependencies before allowed to commit this node
 
 	callback LeafCallback // Callback to invoke if a leaf node it reached on this branch
@@ -89,6 +94,7 @@ type Sync struct {
 	nodeReqs map[common.Hash]*request // Pending requests pertaining to a trie node hash
 	codeReqs map[common.Hash]*request // Pending requests pertaining to a code hash
 	queue    *prque.Prque             // Priority queue with the pending requests
+	fetches  map[int]int              // Number of active fetches per trie node depth
 	bloom    *SyncBloom               // Bloom filter for fast state existence checks
 }
 
@@ -100,14 +106,15 @@ func NewSync(root common.Hash, database ethdb.KeyValueReader, callback LeafCallb
 		nodeReqs: make(map[common.Hash]*request),
 		codeReqs: make(map[common.Hash]*request),
 		queue:    prque.New(nil),
+		fetches:  make(map[int]int),
 		bloom:    bloom,
 	}
-	ts.AddSubTrie(root, 0, common.Hash{}, callback)
+	ts.AddSubTrie(root, nil, common.Hash{}, callback)
 	return ts
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, path []byte, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -128,8 +135,8 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
+		path:     path,
 		hash:     root,
-		depth:    depth,
 		callback: callback,
 	}
 	// If this sub-trie has a designated parent, link them together
@@ -147,7 +154,7 @@ func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callb
 // AddCodeEntry schedules the direct retrieval of a contract code that should not
 // be interpreted as a trie node, but rather accepted and stored into the database
 // as is.
-func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddCodeEntry(hash common.Hash, path []byte, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -170,9 +177,9 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 	}
 	// Assemble the new sub-trie sync request
 	req := &request{
-		hash:  hash,
-		code:  true,
-		depth: depth,
+		path: path,
+		hash: hash,
+		code: true,
 	}
 	// If this sub-trie has a designated parent, link them together
 	if parent != (common.Hash{}) {
@@ -190,7 +197,18 @@ func (s *Sync) AddCodeEntry(hash common.Hash, depth int, parent common.Hash) {
 func (s *Sync) Missing(max int) []common.Hash {
 	var requests []common.Hash
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
-		requests = append(requests, s.queue.PopItem().(common.Hash))
+		// Retrieve th enext item in line
+		item, prio := s.queue.Peek()
+
+		// If we have too many already-pending tasks for this depth, throttle
+		depth := int(prio >> 56)
+		if s.fetches[depth] > maxFetchesPerDepth {
+			break
+		}
+		// Item is allowed to be scheduled, add it to the task list
+		s.queue.Pop()
+		s.fetches[depth]++
+		requests = append(requests, item.(common.Hash))
 	}
 	return requests
 }
@@ -285,7 +303,11 @@ func (s *Sync) schedule(req *request) {
 	// is a trie node and code has same hash. In this case two elements
 	// with same hash and same or different depth will be pushed. But it's
 	// ok the worst case is the second response will be treated as duplicated.
-	s.queue.Push(req.hash, int64(req.depth))
+	prio := int64(len(req.path)) << 56 // depth >= 128 will never happen, storage leaves will be included in their parents
+	for i := 0; i < 14 && i < len(req.path); i++ {
+		prio |= int64(15-req.path[i]) << (52 - i*4) // 15-nibble => lexicographic order
+	}
+	s.queue.Push(req.hash, prio)
 }
 
 // children retrieves all the missing children of a state trie entry for future
@@ -293,23 +315,23 @@ func (s *Sync) schedule(req *request) {
 func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
-		node  node
-		depth int
+		path []byte
+		node node
 	}
 	var children []child
 
 	switch node := (object).(type) {
 	case *shortNode:
 		children = []child{{
-			node:  node.Val,
-			depth: req.depth + len(node.Key),
+			node: node.Val,
+			path: append(append([]byte(nil), req.path...), node.Key...),
 		}}
 	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
-					node:  node.Children[i],
-					depth: req.depth + 1,
+					node: node.Children[i],
+					path: append(append([]byte(nil), req.path...), byte(i)),
 				})
 			}
 		}
@@ -322,7 +344,7 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 		// Notify any external watcher of a new key/value node
 		if req.callback != nil {
 			if node, ok := (child.node).(valueNode); ok {
-				if err := req.callback(node, req.hash); err != nil {
+				if err := req.callback(req.path, node, req.hash); err != nil {
 					return nil, err
 				}
 			}
@@ -346,9 +368,9 @@ func (s *Sync) children(req *request, object node) ([]*request, error) {
 			}
 			// Locally unknown node, schedule for retrieval
 			requests = append(requests, &request{
+				path:     child.path,
 				hash:     hash,
 				parents:  []*request{req},
-				depth:    child.depth,
 				callback: req.callback,
 			})
 		}
@@ -364,9 +386,11 @@ func (s *Sync) commit(req *request) (err error) {
 	if req.code {
 		s.membatch.codes[req.hash] = req.data
 		delete(s.codeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	} else {
 		s.membatch.nodes[req.hash] = req.data
 		delete(s.nodeReqs, req.hash)
+		s.fetches[len(req.path)]--
 	}
 	// Check all parents for completion
 	for _, parent := range req.parents {
diff --git a/trie/trie.go b/trie/trie.go
index 26c3f2c29..7ccd37f87 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -38,7 +38,7 @@ var (
 // LeafCallback is a callback type invoked when a trie operation reaches a leaf
 // node. It's used by state sync and commit to allow handling external references
 // between account and storage tries.
-type LeafCallback func(leaf []byte, parent common.Hash) error
+type LeafCallback func(path []byte, leaf []byte, parent common.Hash) error
 
 // Trie is a Merkle Patricia Trie.
 // The zero value is an empty trie with no database.
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 588562146..2356b7a74 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -565,7 +565,7 @@ func BenchmarkCommitAfterHash(b *testing.B) {
 		benchmarkCommitAfterHash(b, nil)
 	})
 	var a account
-	onleaf := func(leaf []byte, parent common.Hash) error {
+	onleaf := func(path []byte, leaf []byte, parent common.Hash) error {
 		rlp.DecodeBytes(leaf, &a)
 		return nil
 	}
