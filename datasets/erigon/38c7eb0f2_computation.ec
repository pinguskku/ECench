commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
commit 38c7eb0f26eaa8df229d27e92f12e253313a6c8d
Author: Wenbiao Zheng <delweng@gmail.com>
Date:   Tue May 29 23:48:43 2018 +0800

    trie: rename TrieSync to Sync and improve hexToKeybytes (#16804)
    
    This removes a golint warning: type name will be used as trie.TrieSync by
    other packages, and that stutters; consider calling this Sync.
    
    In hexToKeybytes len(hex) is even and (even+1)/2 == even/2, remove the +1.

diff --git a/core/state/sync.go b/core/state/sync.go
index 28fcf6ae0..c566e7907 100644
--- a/core/state/sync.go
+++ b/core/state/sync.go
@@ -25,8 +25,8 @@ import (
 )
 
 // NewStateSync create a new state trie download scheduler.
-func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync {
-	var syncer *trie.TrieSync
+func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.Sync {
+	var syncer *trie.Sync
 	callback := func(leaf []byte, parent common.Hash) error {
 		var obj Account
 		if err := rlp.Decode(bytes.NewReader(leaf), &obj); err != nil {
@@ -36,6 +36,6 @@ func NewStateSync(root common.Hash, database trie.DatabaseReader) *trie.TrieSync
 		syncer.AddRawEntry(common.BytesToHash(obj.CodeHash), 64, parent)
 		return nil
 	}
-	syncer = trie.NewTrieSync(root, database, callback)
+	syncer = trie.NewSync(root, database, callback)
 	return syncer
 }
diff --git a/eth/downloader/statesync.go b/eth/downloader/statesync.go
index 5b4b9ba1b..8d33dfec7 100644
--- a/eth/downloader/statesync.go
+++ b/eth/downloader/statesync.go
@@ -214,7 +214,7 @@ func (d *Downloader) runStateSync(s *stateSync) *stateSync {
 type stateSync struct {
 	d *Downloader // Downloader instance to access and manage current peerset
 
-	sched  *trie.TrieSync             // State trie sync scheduler defining the tasks
+	sched  *trie.Sync                 // State trie sync scheduler defining the tasks
 	keccak hash.Hash                  // Keccak256 hasher to verify deliveries with
 	tasks  map[common.Hash]*stateTask // Set of tasks currently queued for retrieval
 
diff --git a/trie/encoding.go b/trie/encoding.go
index e96a786e4..221fa6d3a 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -83,7 +83,7 @@ func hexToKeybytes(hex []byte) []byte {
 	if len(hex)&1 != 0 {
 		panic("can't convert hex key of odd length")
 	}
-	key := make([]byte, (len(hex)+1)/2)
+	key := make([]byte, len(hex)/2)
 	decodeNibbles(hex, key)
 	return key
 }
diff --git a/trie/sync.go b/trie/sync.go
index 4ae975d04..ccec80c9e 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -68,19 +68,19 @@ func newSyncMemBatch() *syncMemBatch {
 	}
 }
 
-// TrieSync is the main state trie synchronisation scheduler, which provides yet
+// Sync is the main state trie synchronisation scheduler, which provides yet
 // unknown trie hashes to retrieve, accepts node data associated with said hashes
 // and reconstructs the trie step by step until all is done.
-type TrieSync struct {
+type Sync struct {
 	database DatabaseReader           // Persistent database to check for existing entries
 	membatch *syncMemBatch            // Memory buffer to avoid frequest database writes
 	requests map[common.Hash]*request // Pending requests pertaining to a key hash
 	queue    *prque.Prque             // Priority queue with the pending requests
 }
 
-// NewTrieSync creates a new trie data download scheduler.
-func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallback) *TrieSync {
-	ts := &TrieSync{
+// NewSync creates a new trie data download scheduler.
+func NewSync(root common.Hash, database DatabaseReader, callback LeafCallback) *Sync {
+	ts := &Sync{
 		database: database,
 		membatch: newSyncMemBatch(),
 		requests: make(map[common.Hash]*request),
@@ -91,7 +91,7 @@ func NewTrieSync(root common.Hash, database DatabaseReader, callback LeafCallbac
 }
 
 // AddSubTrie registers a new trie to the sync code, rooted at the designated parent.
-func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
+func (s *Sync) AddSubTrie(root common.Hash, depth int, parent common.Hash, callback LeafCallback) {
 	// Short circuit if the trie is empty or already known
 	if root == emptyRoot {
 		return
@@ -126,7 +126,7 @@ func (s *TrieSync) AddSubTrie(root common.Hash, depth int, parent common.Hash, c
 // interpreted as a trie node, but rather accepted and stored into the database
 // as is. This method's goal is to support misc state metadata retrievals (e.g.
 // contract code).
-func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
+func (s *Sync) AddRawEntry(hash common.Hash, depth int, parent common.Hash) {
 	// Short circuit if the entry is empty or already known
 	if hash == emptyState {
 		return
@@ -156,7 +156,7 @@ func (s *TrieSync) AddRawEntry(hash common.Hash, depth int, parent common.Hash)
 }
 
 // Missing retrieves the known missing nodes from the trie for retrieval.
-func (s *TrieSync) Missing(max int) []common.Hash {
+func (s *Sync) Missing(max int) []common.Hash {
 	requests := []common.Hash{}
 	for !s.queue.Empty() && (max == 0 || len(requests) < max) {
 		requests = append(requests, s.queue.PopItem().(common.Hash))
@@ -167,7 +167,7 @@ func (s *TrieSync) Missing(max int) []common.Hash {
 // Process injects a batch of retrieved trie nodes data, returning if something
 // was committed to the database and also the index of an entry if processing of
 // it failed.
-func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
+func (s *Sync) Process(results []SyncResult) (bool, int, error) {
 	committed := false
 
 	for i, item := range results {
@@ -213,7 +213,7 @@ func (s *TrieSync) Process(results []SyncResult) (bool, int, error) {
 
 // Commit flushes the data stored in the internal membatch out to persistent
 // storage, returning the number of items written and any occurred error.
-func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
+func (s *Sync) Commit(dbw ethdb.Putter) (int, error) {
 	// Dump the membatch into a database dbw
 	for i, key := range s.membatch.order {
 		if err := dbw.Put(key[:], s.membatch.batch[key]); err != nil {
@@ -228,14 +228,14 @@ func (s *TrieSync) Commit(dbw ethdb.Putter) (int, error) {
 }
 
 // Pending returns the number of state entries currently pending for download.
-func (s *TrieSync) Pending() int {
+func (s *Sync) Pending() int {
 	return len(s.requests)
 }
 
 // schedule inserts a new state retrieval request into the fetch queue. If there
 // is already a pending request for this node, the new request will be discarded
 // and only a parent reference added to the old one.
-func (s *TrieSync) schedule(req *request) {
+func (s *Sync) schedule(req *request) {
 	// If we're already requesting this node, add a new reference and stop
 	if old, ok := s.requests[req.hash]; ok {
 		old.parents = append(old.parents, req.parents...)
@@ -248,7 +248,7 @@ func (s *TrieSync) schedule(req *request) {
 
 // children retrieves all the missing children of a state trie entry for future
 // retrieval scheduling.
-func (s *TrieSync) children(req *request, object node) ([]*request, error) {
+func (s *Sync) children(req *request, object node) ([]*request, error) {
 	// Gather all the children of the node, irrelevant whether known or not
 	type child struct {
 		node  node
@@ -310,7 +310,7 @@ func (s *TrieSync) children(req *request, object node) ([]*request, error) {
 // commit finalizes a retrieval request and stores it into the membatch. If any
 // of the referencing parent requests complete due to this commit, they are also
 // committed themselves.
-func (s *TrieSync) commit(req *request) (err error) {
+func (s *Sync) commit(req *request) (err error) {
 	// Write the node content to the membatch
 	s.membatch.batch[req.hash] = req.data
 	s.membatch.order = append(s.membatch.order, req.hash)
diff --git a/trie/sync_test.go b/trie/sync_test.go
index 142a6f5b1..c76779e5c 100644
--- a/trie/sync_test.go
+++ b/trie/sync_test.go
@@ -87,14 +87,14 @@ func checkTrieConsistency(db *Database, root common.Hash) error {
 }
 
 // Tests that an empty trie is not scheduled for syncing.
-func TestEmptyTrieSync(t *testing.T) {
+func TestEmptySync(t *testing.T) {
 	dbA := NewDatabase(ethdb.NewMemDatabase())
 	dbB := NewDatabase(ethdb.NewMemDatabase())
 	emptyA, _ := New(common.Hash{}, dbA)
 	emptyB, _ := New(emptyRoot, dbB)
 
 	for i, trie := range []*Trie{emptyA, emptyB} {
-		if req := NewTrieSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
+		if req := NewSync(trie.Hash(), ethdb.NewMemDatabase(), nil).Missing(1); len(req) != 0 {
 			t.Errorf("test %d: content requested for empty trie: %v", i, req)
 		}
 	}
@@ -102,17 +102,17 @@ func TestEmptyTrieSync(t *testing.T) {
 
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go.
-func TestIterativeTrieSyncIndividual(t *testing.T) { testIterativeTrieSync(t, 1) }
-func TestIterativeTrieSyncBatched(t *testing.T)    { testIterativeTrieSync(t, 100) }
+func TestIterativeSyncIndividual(t *testing.T) { testIterativeSync(t, 1) }
+func TestIterativeSyncBatched(t *testing.T)    { testIterativeSync(t, 100) }
 
-func testIterativeTrieSync(t *testing.T, batch int) {
+func testIterativeSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(batch)...)
 	for len(queue) > 0 {
@@ -138,14 +138,14 @@ func testIterativeTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned, and the others sent only later.
-func TestIterativeDelayedTrieSync(t *testing.T) {
+func TestIterativeDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(10000)...)
 	for len(queue) > 0 {
@@ -173,17 +173,17 @@ func TestIterativeDelayedTrieSync(t *testing.T) {
 // Tests that given a root hash, a trie can sync iteratively on a single thread,
 // requesting retrieval tasks and returning all of them in one go, however in a
 // random order.
-func TestIterativeRandomTrieSyncIndividual(t *testing.T) { testIterativeRandomTrieSync(t, 1) }
-func TestIterativeRandomTrieSyncBatched(t *testing.T)    { testIterativeRandomTrieSync(t, 100) }
+func TestIterativeRandomSyncIndividual(t *testing.T) { testIterativeRandomSync(t, 1) }
+func TestIterativeRandomSyncBatched(t *testing.T)    { testIterativeRandomSync(t, 100) }
 
-func testIterativeRandomTrieSync(t *testing.T, batch int) {
+func testIterativeRandomSync(t *testing.T, batch int) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(batch) {
@@ -217,14 +217,14 @@ func testIterativeRandomTrieSync(t *testing.T, batch int) {
 
 // Tests that the trie scheduler can correctly reconstruct the state even if only
 // partial results are returned (Even those randomly), others sent only later.
-func TestIterativeRandomDelayedTrieSync(t *testing.T) {
+func TestIterativeRandomDelayedSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := make(map[common.Hash]struct{})
 	for _, hash := range sched.Missing(10000) {
@@ -264,14 +264,14 @@ func TestIterativeRandomDelayedTrieSync(t *testing.T) {
 
 // Tests that a trie sync will not request nodes multiple times, even if they
 // have such references.
-func TestDuplicateAvoidanceTrieSync(t *testing.T) {
+func TestDuplicateAvoidanceSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, srcData := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	queue := append([]common.Hash{}, sched.Missing(0)...)
 	requested := make(map[common.Hash]struct{})
@@ -304,14 +304,14 @@ func TestDuplicateAvoidanceTrieSync(t *testing.T) {
 
 // Tests that at any point in time during a sync, only complete sub-tries are in
 // the database.
-func TestIncompleteTrieSync(t *testing.T) {
+func TestIncompleteSync(t *testing.T) {
 	// Create a random trie to copy
 	srcDb, srcTrie, _ := makeTestTrie()
 
 	// Create a destination trie and sync with the scheduler
 	diskdb := ethdb.NewMemDatabase()
 	triedb := NewDatabase(diskdb)
-	sched := NewTrieSync(srcTrie.Hash(), diskdb, nil)
+	sched := NewSync(srcTrie.Hash(), diskdb, nil)
 
 	added := []common.Hash{}
 	queue := append([]common.Hash{}, sched.Missing(1)...)
