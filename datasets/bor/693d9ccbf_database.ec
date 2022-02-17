commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
commit 693d9ccbfbbcf7c32d3ff9fd8a432941e129a4ac
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 20 18:26:09 2017 +0200

    trie: more node iterator improvements (#14615)
    
    * ethdb: remove Set
    
    Set deadlocks immediately and isn't part of the Database interface.
    
    * trie: add Err to Iterator
    
    This is useful for testing because the underlying NodeIterator doesn't
    need to be kept in a separate variable just to get the error.
    
    * trie: add LeafKey to iterator, panic when not at leaf
    
    LeafKey is useful for callers that can't interpret Path.
    
    * trie: retry failed seek/peek in iterator Next
    
    Instead of failing iteration irrecoverably, make it so Next retries the
    pending seek or peek every time.
    
    Smaller changes in this commit make this easier to test:
    
    * The iterator previously returned from Next on encountering a hash
      node. This caused it to visit the same path twice.
    * Path returned nibbles with terminator symbol for valueNode attached
      to fullNode, but removed it for valueNode attached to shortNode. Now
      the terminator is always present. This makes Path unique to each node
      and simplifies Leaf.
    
    * trie: add Path to MissingNodeError
    
    The light client trie iterator needs to know the path of the node that's
    missing so it can retrieve a proof for it. NodeIterator.Path is not
    sufficient because it is updated when the node is resolved and actually
    visited by the iterator.
    
    Also remove unused fields. They were added a long time ago before we
    knew which fields would be needed for the light client.

diff --git a/ethdb/memory_database.go b/ethdb/memory_database.go
index 65c487934..a2ee2f2cc 100644
--- a/ethdb/memory_database.go
+++ b/ethdb/memory_database.go
@@ -45,13 +45,6 @@ func (db *MemDatabase) Put(key []byte, value []byte) error {
 	return nil
 }
 
-func (db *MemDatabase) Set(key []byte, value []byte) {
-	db.lock.Lock()
-	defer db.lock.Unlock()
-
-	db.Put(key, value)
-}
-
 func (db *MemDatabase) Get(key []byte) ([]byte, error) {
 	db.lock.RLock()
 	defer db.lock.RUnlock()
diff --git a/trie/errors.go b/trie/errors.go
index e23f9d563..567b80078 100644
--- a/trie/errors.go
+++ b/trie/errors.go
@@ -23,24 +23,13 @@ import (
 )
 
 // MissingNodeError is returned by the trie functions (TryGet, TryUpdate, TryDelete)
-// in the case where a trie node is not present in the local database. Contains
-// information necessary for retrieving the missing node through an ODR service.
-//
-// NodeHash is the hash of the missing node
-//
-// RootHash is the original root of the trie that contains the node
-//
-// PrefixLen is the nibble length of the key prefix that leads from the root to
-// the missing node
-//
-// SuffixLen is the nibble length of the remaining part of the key that hints on
-// which further nodes should also be retrieved (can be zero when there are no
-// such hints in the error message)
+// in the case where a trie node is not present in the local database. It contains
+// information necessary for retrieving the missing node.
 type MissingNodeError struct {
-	RootHash, NodeHash   common.Hash
-	PrefixLen, SuffixLen int
+	NodeHash common.Hash // hash of the missing node
+	Path     []byte      // hex-encoded path to the missing node
 }
 
 func (err *MissingNodeError) Error() string {
-	return fmt.Sprintf("Missing trie node %064x", err.NodeHash)
+	return fmt.Sprintf("missing trie node %x (path %x)", err.NodeHash, err.Path)
 }
diff --git a/trie/iterator.go b/trie/iterator.go
index 26ae1d5ad..76146c0d6 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -24,14 +24,13 @@ import (
 	"github.com/ethereum/go-ethereum/common"
 )
 
-var iteratorEnd = errors.New("end of iteration")
-
 // Iterator is a key-value trie iterator that traverses a Trie.
 type Iterator struct {
 	nodeIt NodeIterator
 
 	Key   []byte // Current data key on which the iterator is positioned on
 	Value []byte // Current data value on which the iterator is positioned on
+	Err   error
 }
 
 // NewIterator creates a new key-value iterator from a node iterator
@@ -45,35 +44,42 @@ func NewIterator(it NodeIterator) *Iterator {
 func (it *Iterator) Next() bool {
 	for it.nodeIt.Next(true) {
 		if it.nodeIt.Leaf() {
-			it.Key = hexToKeybytes(it.nodeIt.Path())
+			it.Key = it.nodeIt.LeafKey()
 			it.Value = it.nodeIt.LeafBlob()
 			return true
 		}
 	}
 	it.Key = nil
 	it.Value = nil
+	it.Err = it.nodeIt.Error()
 	return false
 }
 
 // NodeIterator is an iterator to traverse the trie pre-order.
 type NodeIterator interface {
-	// Hash returns the hash of the current node
-	Hash() common.Hash
-	// Parent returns the hash of the parent of the current node
-	Parent() common.Hash
-	// Leaf returns true iff the current node is a leaf node.
-	Leaf() bool
-	// LeafBlob returns the contents of the node, if it is a leaf.
-	// Callers must not retain references to the return value after calling Next()
-	LeafBlob() []byte
-	// Path returns the hex-encoded path to the current node.
-	// Callers must not retain references to the return value after calling Next()
-	Path() []byte
 	// Next moves the iterator to the next node. If the parameter is false, any child
 	// nodes will be skipped.
 	Next(bool) bool
 	// Error returns the error status of the iterator.
 	Error() error
+
+	// Hash returns the hash of the current node.
+	Hash() common.Hash
+	// Parent returns the hash of the parent of the current node. The hash may be the one
+	// grandparent if the immediate parent is an internal node with no hash.
+	Parent() common.Hash
+	// Path returns the hex-encoded path to the current node.
+	// Callers must not retain references to the return value after calling Next.
+	// For leaf nodes, the last element of the path is the 'terminator symbol' 0x10.
+	Path() []byte
+
+	// Leaf returns true iff the current node is a leaf node.
+	// LeafBlob, LeafKey return the contents and key of the leaf node. These
+	// method panic if the iterator is not positioned at a leaf.
+	// Callers must not retain references to their return value after calling Next
+	Leaf() bool
+	LeafBlob() []byte
+	LeafKey() []byte
 }
 
 // nodeIteratorState represents the iteration state at one particular node of the
@@ -89,8 +95,21 @@ type nodeIteratorState struct {
 type nodeIterator struct {
 	trie  *Trie                // Trie being iterated
 	stack []*nodeIteratorState // Hierarchy of trie nodes persisting the iteration state
-	err   error                // Failure set in case of an internal error in the iterator
 	path  []byte               // Path to the current node
+	err   error                // Failure set in case of an internal error in the iterator
+}
+
+// iteratorEnd is stored in nodeIterator.err when iteration is done.
+var iteratorEnd = errors.New("end of iteration")
+
+// seekError is stored in nodeIterator.err if the initial seek has failed.
+type seekError struct {
+	key []byte
+	err error
+}
+
+func (e seekError) Error() string {
+	return "seek error: " + e.err.Error()
 }
 
 func newNodeIterator(trie *Trie, start []byte) NodeIterator {
@@ -98,60 +117,57 @@ func newNodeIterator(trie *Trie, start []byte) NodeIterator {
 		return new(nodeIterator)
 	}
 	it := &nodeIterator{trie: trie}
-	it.seek(start)
+	it.err = it.seek(start)
 	return it
 }
 
-// Hash returns the hash of the current node
 func (it *nodeIterator) Hash() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].hash
 }
 
-// Parent returns the hash of the parent node
 func (it *nodeIterator) Parent() common.Hash {
 	if len(it.stack) == 0 {
 		return common.Hash{}
 	}
-
 	return it.stack[len(it.stack)-1].parent
 }
 
-// Leaf returns true if the current node is a leaf
 func (it *nodeIterator) Leaf() bool {
-	if len(it.stack) == 0 {
-		return false
-	}
-
-	_, ok := it.stack[len(it.stack)-1].node.(valueNode)
-	return ok
+	return hasTerm(it.path)
 }
 
-// LeafBlob returns the data for the current node, if it is a leaf
 func (it *nodeIterator) LeafBlob() []byte {
-	if len(it.stack) == 0 {
-		return nil
+	if len(it.stack) > 0 {
+		if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return []byte(node)
+		}
 	}
+	panic("not at leaf")
+}
 
-	if node, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
-		return []byte(node)
+func (it *nodeIterator) LeafKey() []byte {
+	if len(it.stack) > 0 {
+		if _, ok := it.stack[len(it.stack)-1].node.(valueNode); ok {
+			return hexToKeybytes(it.path)
+		}
 	}
-	return nil
+	panic("not at leaf")
 }
 
-// Path returns the hex-encoded path to the current node
 func (it *nodeIterator) Path() []byte {
 	return it.path
 }
 
-// Error returns the error set in case of an internal error in the iterator
 func (it *nodeIterator) Error() error {
 	if it.err == iteratorEnd {
 		return nil
 	}
+	if seek, ok := it.err.(seekError); ok {
+		return seek.err
+	}
 	return it.err
 }
 
@@ -160,29 +176,37 @@ func (it *nodeIterator) Error() error {
 // sets the Error field to the encountered failure. If `descend` is false,
 // skips iterating over any subnodes of the current node.
 func (it *nodeIterator) Next(descend bool) bool {
-	if it.err != nil {
+	if it.err == iteratorEnd {
 		return false
 	}
-	// Otherwise step forward with the iterator and report any errors
+	if seek, ok := it.err.(seekError); ok {
+		if it.err = it.seek(seek.key); it.err != nil {
+			return false
+		}
+	}
+	// Otherwise step forward with the iterator and report any errors.
 	state, parentIndex, path, err := it.peek(descend)
-	if err != nil {
-		it.err = err
+	it.err = err
+	if it.err != nil {
 		return false
 	}
 	it.push(state, parentIndex, path)
 	return true
 }
 
-func (it *nodeIterator) seek(prefix []byte) {
+func (it *nodeIterator) seek(prefix []byte) error {
 	// The path we're looking for is the hex encoded key without terminator.
 	key := keybytesToHex(prefix)
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
 		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
-		if err != nil || bytes.Compare(path, key) >= 0 {
-			it.err = err
-			return
+		if err == iteratorEnd {
+			return iteratorEnd
+		} else if err != nil {
+			return seekError{prefix, err}
+		} else if bytes.Compare(path, key) >= 0 {
+			return nil
 		}
 		it.push(state, parentIndex, path)
 	}
@@ -197,7 +221,8 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 		if root != emptyRoot {
 			state.hash = root
 		}
-		return state, nil, nil, nil
+		err := state.resolve(it.trie, nil)
+		return state, nil, nil, err
 	}
 	if !descend {
 		// If we're skipping children, pop the current node first
@@ -205,72 +230,73 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	}
 
 	// Continue iteration to the next child
-	for {
-		if len(it.stack) == 0 {
-			return nil, nil, nil, iteratorEnd
-		}
+	for len(it.stack) > 0 {
 		parent := it.stack[len(it.stack)-1]
 		ancestor := parent.hash
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(*fullNode); ok {
-			// Full node, move to the first non-nil child.
-			for i := parent.index + 1; i < len(node.Children); i++ {
-				child := node.Children[i]
-				if child != nil {
-					hash, _ := child.cache()
-					state := &nodeIteratorState{
-						hash:    common.BytesToHash(hash),
-						node:    child,
-						parent:  ancestor,
-						index:   -1,
-						pathlen: len(it.path),
-					}
-					path := append(it.path, byte(i))
-					parent.index = i - 1
-					return state, &parent.index, path, nil
-				}
+		state, path, ok := it.nextChild(parent, ancestor)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
 			}
-		} else if node, ok := parent.node.(*shortNode); ok {
-			// Short node, return the pointer singleton child
-			if parent.index < 0 {
-				hash, _ := node.Val.cache()
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, iteratorEnd
+}
+
+func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
+	if hash, ok := st.node.(hashNode); ok {
+		resolved, err := tr.resolveHash(hash, path)
+		if err != nil {
+			return err
+		}
+		st.node = resolved
+		st.hash = common.BytesToHash(hash)
+	}
+	return nil
+}
+
+func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
+	switch node := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child.
+		for i := parent.index + 1; i < len(node.Children); i++ {
+			child := node.Children[i]
+			if child != nil {
+				hash, _ := child.cache()
 				state := &nodeIteratorState{
 					hash:    common.BytesToHash(hash),
-					node:    node.Val,
+					node:    child,
 					parent:  ancestor,
 					index:   -1,
 					pathlen: len(it.path),
 				}
-				var path []byte
-				if hasTerm(node.Key) {
-					path = append(it.path, node.Key[:len(node.Key)-1]...)
-				} else {
-					path = append(it.path, node.Key...)
-				}
-				return state, &parent.index, path, nil
+				path := append(it.path, byte(i))
+				parent.index = i - 1
+				return state, path, true
 			}
-		} else if hash, ok := parent.node.(hashNode); ok {
-			// Hash node, resolve the hash child from the database
-			if parent.index < 0 {
-				node, err := it.trie.resolveHash(hash, nil, nil)
-				if err != nil {
-					return it.stack[len(it.stack)-1], &parent.index, it.path, err
-				}
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    node,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				return state, &parent.index, it.path, nil
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := node.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    node.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
 			}
+			path := append(it.path, node.Key...)
+			return state, path, true
 		}
-		// No more child nodes, move back up.
-		it.pop()
 	}
+	return parent, it.path, false
 }
 
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
@@ -288,23 +314,21 @@ func (it *nodeIterator) pop() {
 }
 
 func compareNodes(a, b NodeIterator) int {
-	cmp := bytes.Compare(a.Path(), b.Path())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Path(), b.Path()); cmp != 0 {
 		return cmp
 	}
-
 	if a.Leaf() && !b.Leaf() {
 		return -1
 	} else if b.Leaf() && !a.Leaf() {
 		return 1
 	}
-
-	cmp = bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes())
-	if cmp != 0 {
+	if cmp := bytes.Compare(a.Hash().Bytes(), b.Hash().Bytes()); cmp != 0 {
 		return cmp
 	}
-
-	return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	if a.Leaf() && b.Leaf() {
+		return bytes.Compare(a.LeafBlob(), b.LeafBlob())
+	}
+	return 0
 }
 
 type differenceIterator struct {
@@ -341,6 +365,10 @@ func (it *differenceIterator) LeafBlob() []byte {
 	return it.b.LeafBlob()
 }
 
+func (it *differenceIterator) LeafKey() []byte {
+	return it.b.LeafKey()
+}
+
 func (it *differenceIterator) Path() []byte {
 	return it.b.Path()
 }
@@ -410,7 +438,6 @@ func (h *nodeIteratorHeap) Pop() interface{} {
 type unionIterator struct {
 	items *nodeIteratorHeap // Nodes returned are the union of the ones in these iterators
 	count int               // Number of nodes scanned across all tries
-	err   error             // The error, if one has been encountered
 }
 
 // NewUnionIterator constructs a NodeIterator that iterates over elements in the union
@@ -421,9 +448,7 @@ func NewUnionIterator(iters []NodeIterator) (NodeIterator, *int) {
 	copy(h, iters)
 	heap.Init(&h)
 
-	ui := &unionIterator{
-		items: &h,
-	}
+	ui := &unionIterator{items: &h}
 	return ui, &ui.count
 }
 
@@ -443,6 +468,10 @@ func (it *unionIterator) LeafBlob() []byte {
 	return (*it.items)[0].LeafBlob()
 }
 
+func (it *unionIterator) LeafKey() []byte {
+	return (*it.items)[0].LeafKey()
+}
+
 func (it *unionIterator) Path() []byte {
 	return (*it.items)[0].Path()
 }
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index f161fd99d..4808d8b0c 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"fmt"
+	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
@@ -239,8 +240,8 @@ func TestUnionIterator(t *testing.T) {
 
 	all := []struct{ k, v string }{
 		{"aardvark", "c"},
-		{"barb", "bd"},
 		{"barb", "ba"},
+		{"barb", "bd"},
 		{"bard", "bc"},
 		{"bars", "bb"},
 		{"bars", "be"},
@@ -267,3 +268,107 @@ func TestUnionIterator(t *testing.T) {
 		t.Errorf("Iterator returned extra values.")
 	}
 }
+
+func TestIteratorNoDups(t *testing.T) {
+	var tr Trie
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+}
+
+// This test checks that nodeIterator.Next can be retried after inserting missing trie nodes.
+func TestIteratorContinueAfterError(t *testing.T) {
+	db, _ := ethdb.NewMemDatabase()
+	tr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		tr.Update([]byte(val.k), []byte(val.v))
+	}
+	tr.Commit()
+	wantNodeCount := checkIteratorNoDups(t, tr.NodeIterator(nil), nil)
+	keys := db.Keys()
+	t.Log("node count", wantNodeCount)
+
+	for i := 0; i < 20; i++ {
+		// Create trie that will load all nodes from DB.
+		tr, _ := New(tr.Hash(), db)
+
+		// Remove a random node from the database. It can't be the root node
+		// because that one is already loaded.
+		var rkey []byte
+		for {
+			if rkey = keys[rand.Intn(len(keys))]; !bytes.Equal(rkey, tr.Hash().Bytes()) {
+				break
+			}
+		}
+		rval, _ := db.Get(rkey)
+		db.Delete(rkey)
+
+		// Iterate until the error is hit.
+		seen := make(map[string]bool)
+		it := tr.NodeIterator(nil)
+		checkIteratorNoDups(t, it, seen)
+		missing, ok := it.Error().(*MissingNodeError)
+		if !ok || !bytes.Equal(missing.NodeHash[:], rkey) {
+			t.Fatal("didn't hit missing node, got", it.Error())
+		}
+
+		// Add the node back and continue iteration.
+		db.Put(rkey, rval)
+		checkIteratorNoDups(t, it, seen)
+		if it.Error() != nil {
+			t.Fatal("unexpected error", it.Error())
+		}
+		if len(seen) != wantNodeCount {
+			t.Fatal("wrong node iteration count, got", len(seen), "want", wantNodeCount)
+		}
+	}
+}
+
+// Similar to the test above, this one checks that failure to create nodeIterator at a
+// certain key prefix behaves correctly when Next is called. The expectation is that Next
+// should retry seeking before returning true for the first time.
+func TestIteratorContinueAfterSeekError(t *testing.T) {
+	// Commit test trie to db, then remove the node containing "bars".
+	db, _ := ethdb.NewMemDatabase()
+	ctr, _ := New(common.Hash{}, db)
+	for _, val := range testdata1 {
+		ctr.Update([]byte(val.k), []byte(val.v))
+	}
+	root, _ := ctr.Commit()
+	barNodeHash := common.HexToHash("05041990364eb72fcb1127652ce40d8bab765f2bfe53225b1170d276cc101c2e")
+	barNode, _ := db.Get(barNodeHash[:])
+	db.Delete(barNodeHash[:])
+
+	// Create a new iterator that seeks to "bars". Seeking can't proceed because
+	// the node is missing.
+	tr, _ := New(root, db)
+	it := tr.NodeIterator([]byte("bars"))
+	missing, ok := it.Error().(*MissingNodeError)
+	if !ok {
+		t.Fatal("want MissingNodeError, got", it.Error())
+	} else if missing.NodeHash != barNodeHash {
+		t.Fatal("wrong node missing")
+	}
+
+	// Reinsert the missing node.
+	db.Put(barNodeHash[:], barNode[:])
+
+	// Check that iteration produces the right set of values.
+	if err := checkIteratorOrder(testdata1[2:], NewIterator(it)); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) int {
+	if seen == nil {
+		seen = make(map[string]bool)
+	}
+	for it.Next(true) {
+		if seen[string(it.Path())] {
+			t.Fatalf("iterator visited node path %x twice", it.Path())
+		}
+		seen[string(it.Path())] = true
+	}
+	return len(seen)
+}
diff --git a/trie/proof.go b/trie/proof.go
index fb7734b86..1f8f76b1b 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -58,7 +58,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			nodes = append(nodes, n)
 		case hashNode:
 			var err error
-			tn, err = t.resolveHash(n, nil, nil)
+			tn, err = t.resolveHash(n, nil)
 			if err != nil {
 				log.Error(fmt.Sprintf("Unhandled trie error: %v", err))
 				return nil
diff --git a/trie/trie.go b/trie/trie.go
index cbe496574..a3151b1ce 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -116,7 +116,7 @@ func New(root common.Hash, db Database) (*Trie, error) {
 		if db == nil {
 			panic("trie.New: cannot use existing root without a database")
 		}
-		rootnode, err := trie.resolveHash(root[:], nil, nil)
+		rootnode, err := trie.resolveHash(root[:], nil)
 		if err != nil {
 			return nil, err
 		}
@@ -180,7 +180,7 @@ func (t *Trie) tryGet(origNode node, key []byte, pos int) (value []byte, newnode
 		}
 		return value, n, didResolve, err
 	case hashNode:
-		child, err := t.resolveHash(n, key[:pos], key[pos:])
+		child, err := t.resolveHash(n, key[:pos])
 		if err != nil {
 			return nil, n, true, err
 		}
@@ -283,7 +283,7 @@ func (t *Trie) insert(n node, prefix, key []byte, value node) (bool, node, error
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and insert into it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -388,7 +388,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 				// shortNode{..., shortNode{...}}.  Since the entry
 				// might not be loaded yet, resolve it just for this
 				// check.
-				cnode, err := t.resolve(n.Children[pos], prefix, []byte{byte(pos)})
+				cnode, err := t.resolve(n.Children[pos], prefix)
 				if err != nil {
 					return false, nil, err
 				}
@@ -414,7 +414,7 @@ func (t *Trie) delete(n node, prefix, key []byte) (bool, node, error) {
 		// We've hit a part of the trie that isn't loaded yet. Load
 		// the node and delete from it. This leaves all child nodes on
 		// the path to the value in the trie.
-		rn, err := t.resolveHash(n, prefix, key)
+		rn, err := t.resolveHash(n, prefix)
 		if err != nil {
 			return false, nil, err
 		}
@@ -436,24 +436,19 @@ func concat(s1 []byte, s2 ...byte) []byte {
 	return r
 }
 
-func (t *Trie) resolve(n node, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolve(n node, prefix []byte) (node, error) {
 	if n, ok := n.(hashNode); ok {
-		return t.resolveHash(n, prefix, suffix)
+		return t.resolveHash(n, prefix)
 	}
 	return n, nil
 }
 
-func (t *Trie) resolveHash(n hashNode, prefix, suffix []byte) (node, error) {
+func (t *Trie) resolveHash(n hashNode, prefix []byte) (node, error) {
 	cacheMissCounter.Inc(1)
 
 	enc, err := t.db.Get(n)
 	if err != nil || enc == nil {
-		return nil, &MissingNodeError{
-			RootHash:  t.originalRoot,
-			NodeHash:  common.BytesToHash(n),
-			PrefixLen: len(prefix),
-			SuffixLen: len(suffix),
-		}
+		return nil, &MissingNodeError{NodeHash: common.BytesToHash(n), Path: prefix}
 	}
 	dec := mustDecodeNode(n, enc, t.cachegen)
 	return dec, nil
diff --git a/trie/trie_test.go b/trie/trie_test.go
index 61adbba0c..1c9095070 100644
--- a/trie/trie_test.go
+++ b/trie/trie_test.go
@@ -19,6 +19,7 @@ package trie
 import (
 	"bytes"
 	"encoding/binary"
+	"errors"
 	"fmt"
 	"io/ioutil"
 	"math/rand"
@@ -34,7 +35,7 @@ import (
 
 func init() {
 	spew.Config.Indent = "    "
-	spew.Config.DisableMethods = true
+	spew.Config.DisableMethods = false
 }
 
 // Used for testing
@@ -357,6 +358,7 @@ type randTestStep struct {
 	op    int
 	key   []byte // for opUpdate, opDelete, opGet
 	value []byte // for opUpdate
+	err   error  // for debugging
 }
 
 const (
@@ -406,7 +408,7 @@ func runRandTest(rt randTest) bool {
 	tr, _ := New(common.Hash{}, db)
 	values := make(map[string]string) // tracks content of the trie
 
-	for _, step := range rt {
+	for i, step := range rt {
 		switch step.op {
 		case opUpdate:
 			tr.Update(step.key, step.value)
@@ -418,23 +420,22 @@ func runRandTest(rt randTest) bool {
 			v := tr.Get(step.key)
 			want := values[string(step.key)]
 			if string(v) != want {
-				fmt.Printf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
-				return false
+				rt[i].err = fmt.Errorf("mismatch for key 0x%x, got 0x%x want 0x%x", step.key, v, want)
 			}
 		case opCommit:
-			if _, err := tr.Commit(); err != nil {
-				panic(err)
-			}
+			_, rt[i].err = tr.Commit()
 		case opHash:
 			tr.Hash()
 		case opReset:
 			hash, err := tr.Commit()
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			newtr, err := New(hash, db)
 			if err != nil {
-				panic(err)
+				rt[i].err = err
+				return false
 			}
 			tr = newtr
 		case opItercheckhash:
@@ -444,17 +445,20 @@ func runRandTest(rt randTest) bool {
 				checktr.Update(it.Key, it.Value)
 			}
 			if tr.Hash() != checktr.Hash() {
-				fmt.Println("hashes not equal")
-				return false
+				rt[i].err = fmt.Errorf("hash mismatch in opItercheckhash")
 			}
 		case opCheckCacheInvariant:
-			return checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+			rt[i].err = checkCacheInvariant(tr.root, nil, tr.cachegen, false, 0)
+		}
+		// Abort the test on error.
+		if rt[i].err != nil {
+			return false
 		}
 	}
 	return true
 }
 
-func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) bool {
+func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool, depth int) error {
 	var children []node
 	var flag nodeFlag
 	switch n := n.(type) {
@@ -465,33 +469,34 @@ func checkCacheInvariant(n, parent node, parentCachegen uint16, parentDirty bool
 		flag = n.flags
 		children = n.Children[:]
 	default:
-		return true
+		return nil
 	}
 
-	showerror := func() {
-		fmt.Printf("at depth %d node %s", depth, spew.Sdump(n))
-		fmt.Printf("parent: %s", spew.Sdump(parent))
+	errorf := func(format string, args ...interface{}) error {
+		msg := fmt.Sprintf(format, args...)
+		msg += fmt.Sprintf("\nat depth %d node %s", depth, spew.Sdump(n))
+		msg += fmt.Sprintf("parent: %s", spew.Sdump(parent))
+		return errors.New(msg)
 	}
 	if flag.gen > parentCachegen {
-		fmt.Printf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	if depth > 0 && !parentDirty && flag.dirty {
-		fmt.Printf("cache invariant violation: child is dirty but parent isn't\n")
-		showerror()
-		return false
+		return errorf("cache invariant violation: %d > %d\n", flag.gen, parentCachegen)
 	}
 	for _, child := range children {
-		if !checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1) {
-			return false
+		if err := checkCacheInvariant(child, n, flag.gen, flag.dirty, depth+1); err != nil {
+			return err
 		}
 	}
-	return true
+	return nil
 }
 
 func TestRandom(t *testing.T) {
 	if err := quick.Check(runRandTest, nil); err != nil {
+		if cerr, ok := err.(*quick.CheckError); ok {
+			t.Fatalf("random test iteration %d failed: %s", cerr.Count, spew.Sdump(cerr.In))
+		}
 		t.Fatal(err)
 	}
 }
