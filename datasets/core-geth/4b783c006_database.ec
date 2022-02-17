commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
commit 4b783c0064661be55fd35b765c2a90d1f9b9abcb
Author: Martin Holst Swende <martin@swende.se>
Date:   Wed Apr 21 12:25:26 2021 +0200

    trie: improve the node iterator seek operation (#22470)
    
    This change improves the efficiency of the nodeIterator seek
    operation. Previously, seek essentially ran the iterator forward
    until it found the matching node. With this change, it skips
    over fullnode children and avoids resolving them from the database.

diff --git a/trie/iterator.go b/trie/iterator.go
index 76d437c40..4f72258a1 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -243,7 +243,7 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	key = key[:len(key)-1]
 	// Move forward until we're just before the closest match to key.
 	for {
-		state, parentIndex, path, err := it.peek(bytes.HasPrefix(key, it.path))
+		state, parentIndex, path, err := it.peekSeek(key)
 		if err == errIteratorEnd {
 			return errIteratorEnd
 		} else if err != nil {
@@ -255,16 +255,21 @@ func (it *nodeIterator) seek(prefix []byte) error {
 	}
 }
 
+// init initializes the the iterator.
+func (it *nodeIterator) init() (*nodeIteratorState, error) {
+	root := it.trie.Hash()
+	state := &nodeIteratorState{node: it.trie.root, index: -1}
+	if root != emptyRoot {
+		state.hash = root
+	}
+	return state, state.resolve(it.trie, nil)
+}
+
 // peek creates the next state of the iterator.
 func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
 	if len(it.stack) == 0 {
-		// Initialize the iterator if we've just started.
-		root := it.trie.Hash()
-		state := &nodeIteratorState{node: it.trie.root, index: -1}
-		if root != emptyRoot {
-			state.hash = root
-		}
-		err := state.resolve(it.trie, nil)
+		state, err := it.init()
 		return state, nil, nil, err
 	}
 	if !descend {
@@ -292,6 +297,39 @@ func (it *nodeIterator) peek(descend bool) (*nodeIteratorState, *int, []byte, er
 	return nil, nil, nil, errIteratorEnd
 }
 
+// peekSeek is like peek, but it also tries to skip resolving hashes by skipping
+// over the siblings that do not lead towards the desired seek position.
+func (it *nodeIterator) peekSeek(seekKey []byte) (*nodeIteratorState, *int, []byte, error) {
+	// Initialize the iterator if we've just started.
+	if len(it.stack) == 0 {
+		state, err := it.init()
+		return state, nil, nil, err
+	}
+	if !bytes.HasPrefix(seekKey, it.path) {
+		// If we're skipping children, pop the current node first
+		it.pop()
+	}
+
+	// Continue iteration to the next child
+	for len(it.stack) > 0 {
+		parent := it.stack[len(it.stack)-1]
+		ancestor := parent.hash
+		if (ancestor == common.Hash{}) {
+			ancestor = parent.parent
+		}
+		state, path, ok := it.nextChildAt(parent, ancestor, seekKey)
+		if ok {
+			if err := state.resolve(it.trie, path); err != nil {
+				return parent, &parent.index, path, err
+			}
+			return state, &parent.index, path, nil
+		}
+		// No more child nodes, move back up.
+		it.pop()
+	}
+	return nil, nil, nil, errIteratorEnd
+}
+
 func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	if hash, ok := st.node.(hashNode); ok {
 		resolved, err := tr.resolveHash(hash, path)
@@ -304,25 +342,38 @@ func (st *nodeIteratorState) resolve(tr *Trie, path []byte) error {
 	return nil
 }
 
+func findChild(n *fullNode, index int, path []byte, ancestor common.Hash) (node, *nodeIteratorState, []byte, int) {
+	var (
+		child     node
+		state     *nodeIteratorState
+		childPath []byte
+	)
+	for ; index < len(n.Children); index++ {
+		if n.Children[index] != nil {
+			child = n.Children[index]
+			hash, _ := child.cache()
+			state = &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    child,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(path),
+			}
+			childPath = append(childPath, path...)
+			childPath = append(childPath, byte(index))
+			return child, state, childPath, index
+		}
+	}
+	return nil, nil, nil, 0
+}
+
 func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Hash) (*nodeIteratorState, []byte, bool) {
 	switch node := parent.node.(type) {
 	case *fullNode:
-		// Full node, move to the first non-nil child.
-		for i := parent.index + 1; i < len(node.Children); i++ {
-			child := node.Children[i]
-			if child != nil {
-				hash, _ := child.cache()
-				state := &nodeIteratorState{
-					hash:    common.BytesToHash(hash),
-					node:    child,
-					parent:  ancestor,
-					index:   -1,
-					pathlen: len(it.path),
-				}
-				path := append(it.path, byte(i))
-				parent.index = i - 1
-				return state, path, true
-			}
+		//Full node, move to the first non-nil child.
+		if child, state, path, index := findChild(node, parent.index+1, it.path, ancestor); child != nil {
+			parent.index = index - 1
+			return state, path, true
 		}
 	case *shortNode:
 		// Short node, return the pointer singleton child
@@ -342,6 +393,52 @@ func (it *nodeIterator) nextChild(parent *nodeIteratorState, ancestor common.Has
 	return parent, it.path, false
 }
 
+// nextChildAt is similar to nextChild, except that it targets a child as close to the
+// target key as possible, thus skipping siblings.
+func (it *nodeIterator) nextChildAt(parent *nodeIteratorState, ancestor common.Hash, key []byte) (*nodeIteratorState, []byte, bool) {
+	switch n := parent.node.(type) {
+	case *fullNode:
+		// Full node, move to the first non-nil child before the desired key position
+		child, state, path, index := findChild(n, parent.index+1, it.path, ancestor)
+		if child == nil {
+			// No more children in this fullnode
+			return parent, it.path, false
+		}
+		// If the child we found is already past the seek position, just return it.
+		if bytes.Compare(path, key) >= 0 {
+			parent.index = index - 1
+			return state, path, true
+		}
+		// The child is before the seek position. Try advancing
+		for {
+			nextChild, nextState, nextPath, nextIndex := findChild(n, index+1, it.path, ancestor)
+			// If we run out of children, or skipped past the target, return the
+			// previous one
+			if nextChild == nil || bytes.Compare(nextPath, key) >= 0 {
+				parent.index = index - 1
+				return state, path, true
+			}
+			// We found a better child closer to the target
+			state, path, index = nextState, nextPath, nextIndex
+		}
+	case *shortNode:
+		// Short node, return the pointer singleton child
+		if parent.index < 0 {
+			hash, _ := n.Val.cache()
+			state := &nodeIteratorState{
+				hash:    common.BytesToHash(hash),
+				node:    n.Val,
+				parent:  ancestor,
+				index:   -1,
+				pathlen: len(it.path),
+			}
+			path := append(it.path, n.Key...)
+			return state, path, true
+		}
+	}
+	return parent, it.path, false
+}
+
 func (it *nodeIterator) push(state *nodeIteratorState, parentIndex *int, path []byte) {
 	it.path = path
 	it.stack = append(it.stack, state)
diff --git a/trie/iterator_test.go b/trie/iterator_test.go
index 75a0a99e5..2518f7bac 100644
--- a/trie/iterator_test.go
+++ b/trie/iterator_test.go
@@ -18,11 +18,14 @@ package trie
 
 import (
 	"bytes"
+	"encoding/binary"
 	"fmt"
 	"math/rand"
 	"testing"
 
 	"github.com/ethereum/go-ethereum/common"
+	"github.com/ethereum/go-ethereum/crypto"
+	"github.com/ethereum/go-ethereum/ethdb"
 	"github.com/ethereum/go-ethereum/ethdb/memorydb"
 )
 
@@ -440,3 +443,81 @@ func checkIteratorNoDups(t *testing.T, it NodeIterator, seen map[string]bool) in
 	}
 	return len(seen)
 }
+
+type loggingDb struct {
+	getCount uint64
+	backend  ethdb.KeyValueStore
+}
+
+func (l *loggingDb) Has(key []byte) (bool, error) {
+	return l.backend.Has(key)
+}
+
+func (l *loggingDb) Get(key []byte) ([]byte, error) {
+	l.getCount++
+	return l.backend.Get(key)
+}
+
+func (l *loggingDb) Put(key []byte, value []byte) error {
+	return l.backend.Put(key, value)
+}
+
+func (l *loggingDb) Delete(key []byte) error {
+	return l.backend.Delete(key)
+}
+
+func (l *loggingDb) NewBatch() ethdb.Batch {
+	return l.backend.NewBatch()
+}
+
+func (l *loggingDb) NewIterator(prefix []byte, start []byte) ethdb.Iterator {
+	fmt.Printf("NewIterator\n")
+	return l.backend.NewIterator(prefix, start)
+}
+func (l *loggingDb) Stat(property string) (string, error) {
+	return l.backend.Stat(property)
+}
+
+func (l *loggingDb) Compact(start []byte, limit []byte) error {
+	return l.backend.Compact(start, limit)
+}
+
+func (l *loggingDb) Close() error {
+	return l.backend.Close()
+}
+
+// makeLargeTestTrie create a sample test trie
+func makeLargeTestTrie() (*Database, *SecureTrie, *loggingDb) {
+	// Create an empty trie
+	logDb := &loggingDb{0, memorydb.New()}
+	triedb := NewDatabase(logDb)
+	trie, _ := NewSecure(common.Hash{}, triedb)
+
+	// Fill it with some arbitrary data
+	for i := 0; i < 10000; i++ {
+		key := make([]byte, 32)
+		val := make([]byte, 32)
+		binary.BigEndian.PutUint64(key, uint64(i))
+		binary.BigEndian.PutUint64(val, uint64(i))
+		key = crypto.Keccak256(key)
+		val = crypto.Keccak256(val)
+		trie.Update(key, val)
+	}
+	trie.Commit(nil)
+	// Return the generated trie
+	return triedb, trie, logDb
+}
+
+// Tests that the node iterator indeed walks over the entire database contents.
+func TestNodeIteratorLargeTrie(t *testing.T) {
+	// Create some arbitrary test trie to iterate
+	db, trie, logDb := makeLargeTestTrie()
+	db.Cap(0) // flush everything
+	// Do a seek operation
+	trie.NodeIterator(common.FromHex("0x77667766776677766778855885885885"))
+	// master: 24 get operations
+	// this pr: 5 get operations
+	if have, want := logDb.getCount, uint64(5); have != want {
+		t.Fatalf("Too many lookups during seek, have %d want %d", have, want)
+	}
+}
