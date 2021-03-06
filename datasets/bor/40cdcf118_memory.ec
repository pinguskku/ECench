commit 40cdcf1183df235e4b32cfdbf6182a00a0e49f24
Author: Felix Lange <fjl@twurst.com>
Date:   Fri Oct 14 18:04:33 2016 +0200

    trie, core/state: improve memory usage and performance (#3135)
    
    * trie: store nodes as pointers
    
    This avoids memory copies when unwrapping node interface values.
    
    name      old time/op  new time/op  delta
    Get        388ns ± 8%   215ns ± 2%  -44.56%  (p=0.000 n=15+15)
    GetDB      363ns ± 3%   202ns ± 2%  -44.21%  (p=0.000 n=15+15)
    UpdateBE  1.57µs ± 2%  1.29µs ± 3%  -17.80%  (p=0.000 n=13+15)
    UpdateLE  1.92µs ± 2%  1.61µs ± 2%  -16.25%  (p=0.000 n=14+14)
    HashBE    2.16µs ± 6%  2.18µs ± 6%     ~     (p=0.436 n=15+15)
    HashLE    7.43µs ± 3%  7.21µs ± 3%   -2.96%  (p=0.000 n=15+13)
    
    * trie: close temporary databases in GetDB benchmark
    
    * trie: don't keep []byte from DB load around
    
    Nodes decoded from a DB load kept hashes and values as sub-slices of
    the DB value. This can be a problem because loading from leveldb often
    returns []byte with a cap that's larger than necessary, increasing
    memory usage.
    
    * trie: unload old cached nodes
    
    * trie, core/state: use cache unloading for account trie
    
    * trie: use explicit private flags (fixes Go 1.5 reflection issue).
    
    * trie: fixup cachegen overflow at request of nick
    
    * core/state: rename journal size constant

diff --git a/core/blockchain.go b/core/blockchain.go
index f68f4fc0d..7657fce78 100644
--- a/core/blockchain.go
+++ b/core/blockchain.go
@@ -269,7 +269,7 @@ func (self *BlockChain) FastSyncCommitHead(hash common.Hash) error {
 	if block == nil {
 		return fmt.Errorf("non existent block [%x…]", hash[:4])
 	}
-	if _, err := trie.NewSecure(block.Root(), self.chainDb); err != nil {
+	if _, err := trie.NewSecure(block.Root(), self.chainDb, 0); err != nil {
 		return err
 	}
 	// If all checks out, manually set the head block
diff --git a/core/state/state_object.go b/core/state/state_object.go
index 6eab27d9e..edb073173 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -137,9 +137,9 @@ func (self *StateObject) markSuicided() {
 func (c *StateObject) getTrie(db trie.Database) *trie.SecureTrie {
 	if c.trie == nil {
 		var err error
-		c.trie, err = trie.NewSecure(c.data.Root, db)
+		c.trie, err = trie.NewSecure(c.data.Root, db, 0)
 		if err != nil {
-			c.trie, _ = trie.NewSecure(common.Hash{}, db)
+			c.trie, _ = trie.NewSecure(common.Hash{}, db, 0)
 			c.setError(fmt.Errorf("can't create storage trie: %v", err))
 		}
 	}
diff --git a/core/state/statedb.go b/core/state/statedb.go
index ec9e9392f..dcb897628 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -41,7 +41,10 @@ var StartingNonce uint64
 const (
 	// Number of past tries to keep. The arbitrarily chosen value here
 	// is max uncle depth + 1.
-	maxTrieCacheLength = 8
+	maxPastTries = 8
+
+	// Trie cache generation limit.
+	maxTrieCacheGen = 100
 
 	// Number of codehash->size associations to keep.
 	codeSizeCacheSize = 100000
@@ -86,7 +89,7 @@ type StateDB struct {
 
 // Create a new state from a given trie
 func New(root common.Hash, db ethdb.Database) (*StateDB, error) {
-	tr, err := trie.NewSecure(root, db)
+	tr, err := trie.NewSecure(root, db, maxTrieCacheGen)
 	if err != nil {
 		return nil, err
 	}
@@ -155,14 +158,14 @@ func (self *StateDB) openTrie(root common.Hash) (*trie.SecureTrie, error) {
 			return &tr, nil
 		}
 	}
-	return trie.NewSecure(root, self.db)
+	return trie.NewSecure(root, self.db, maxTrieCacheGen)
 }
 
 func (self *StateDB) pushTrie(t *trie.SecureTrie) {
 	self.lock.Lock()
 	defer self.lock.Unlock()
 
-	if len(self.pastTries) >= maxTrieCacheLength {
+	if len(self.pastTries) >= maxPastTries {
 		copy(self.pastTries, self.pastTries[1:])
 		self.pastTries[len(self.pastTries)-1] = t
 	} else {
diff --git a/eth/downloader/downloader_test.go b/eth/downloader/downloader_test.go
index ae9a85ae1..366c248bb 100644
--- a/eth/downloader/downloader_test.go
+++ b/eth/downloader/downloader_test.go
@@ -286,7 +286,7 @@ func (dl *downloadTester) headFastBlock() *types.Block {
 func (dl *downloadTester) commitHeadBlock(hash common.Hash) error {
 	// For now only check that the state trie is correct
 	if block := dl.getBlock(hash); block != nil {
-		_, err := trie.NewSecure(block.Root(), dl.stateDb)
+		_, err := trie.NewSecure(block.Root(), dl.stateDb, 0)
 		return err
 	}
 	return fmt.Errorf("non existent block: %x", hash[:4])
diff --git a/light/trie.go b/light/trie.go
index e9c96ea48..42a943d50 100644
--- a/light/trie.go
+++ b/light/trie.go
@@ -79,7 +79,7 @@ func (t *LightTrie) do(ctx context.Context, fallbackKey []byte, fn func() error)
 func (t *LightTrie) Get(ctx context.Context, key []byte) (res []byte, err error) {
 	err = t.do(ctx, key, func() (err error) {
 		if t.trie == nil {
-			t.trie, err = trie.NewSecure(t.originalRoot, t.db)
+			t.trie, err = trie.NewSecure(t.originalRoot, t.db, 0)
 		}
 		if err == nil {
 			res, err = t.trie.TryGet(key)
@@ -98,7 +98,7 @@ func (t *LightTrie) Get(ctx context.Context, key []byte) (res []byte, err error)
 func (t *LightTrie) Update(ctx context.Context, key, value []byte) (err error) {
 	err = t.do(ctx, key, func() (err error) {
 		if t.trie == nil {
-			t.trie, err = trie.NewSecure(t.originalRoot, t.db)
+			t.trie, err = trie.NewSecure(t.originalRoot, t.db, 0)
 		}
 		if err == nil {
 			err = t.trie.TryUpdate(key, value)
@@ -112,7 +112,7 @@ func (t *LightTrie) Update(ctx context.Context, key, value []byte) (err error) {
 func (t *LightTrie) Delete(ctx context.Context, key []byte) (err error) {
 	err = t.do(ctx, key, func() (err error) {
 		if t.trie == nil {
-			t.trie, err = trie.NewSecure(t.originalRoot, t.db)
+			t.trie, err = trie.NewSecure(t.originalRoot, t.db, 0)
 		}
 		if err == nil {
 			err = t.trie.TryDelete(key)
diff --git a/trie/hasher.go b/trie/hasher.go
index 87e02fb85..e395e00d7 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -27,8 +27,9 @@ import (
 )
 
 type hasher struct {
-	tmp *bytes.Buffer
-	sha hash.Hash
+	tmp                  *bytes.Buffer
+	sha                  hash.Hash
+	cachegen, cachelimit uint16
 }
 
 // hashers live in a global pool.
@@ -38,8 +39,10 @@ var hasherPool = sync.Pool{
 	},
 }
 
-func newHasher() *hasher {
-	return hasherPool.Get().(*hasher)
+func newHasher(cachegen, cachelimit uint16) *hasher {
+	h := hasherPool.Get().(*hasher)
+	h.cachegen, h.cachelimit = cachegen, cachelimit
+	return h
 }
 
 func returnHasherToPool(h *hasher) {
@@ -50,8 +53,18 @@ func returnHasherToPool(h *hasher) {
 // original node initialzied with the computed hash to replace the original one.
 func (h *hasher) hash(n node, db DatabaseWriter, force bool) (node, node, error) {
 	// If we're not storing the node, just hashing, use avaialble cached data
-	if hash, dirty := n.cache(); hash != nil && (db == nil || !dirty) {
-		return hash, n, nil
+	if hash, dirty := n.cache(); hash != nil {
+		if db == nil {
+			return hash, n, nil
+		}
+		if n.canUnload(h.cachegen, h.cachelimit) {
+			// Evict the node from cache. All of its subnodes will have a lower or equal
+			// cache generation number.
+			return hash, hash, nil
+		}
+		if !dirty {
+			return hash, n, nil
+		}
 	}
 	// Trie not processed yet or needs storage, walk the children
 	collapsed, cached, err := h.hashChildren(n, db)
@@ -62,19 +75,21 @@ func (h *hasher) hash(n node, db DatabaseWriter, force bool) (node, node, error)
 	if err != nil {
 		return hashNode{}, n, err
 	}
-	// Cache the hash and RLP blob of the ndoe for later reuse
+	// Cache the hash of the ndoe for later reuse.
 	if hash, ok := hashed.(hashNode); ok && !force {
 		switch cached := cached.(type) {
-		case shortNode:
-			cached.hash = hash
+		case *shortNode:
+			cached = cached.copy()
+			cached.flags.hash = hash
 			if db != nil {
-				cached.dirty = false
+				cached.flags.dirty = false
 			}
 			return hashed, cached, nil
-		case fullNode:
-			cached.hash = hash
+		case *fullNode:
+			cached = cached.copy()
+			cached.flags.hash = hash
 			if db != nil {
-				cached.dirty = false
+				cached.flags.dirty = false
 			}
 			return hashed, cached, nil
 		}
@@ -89,40 +104,42 @@ func (h *hasher) hashChildren(original node, db DatabaseWriter) (node, node, err
 	var err error
 
 	switch n := original.(type) {
-	case shortNode:
+	case *shortNode:
 		// Hash the short node's child, caching the newly hashed subtree
-		cached := n
-		cached.Key = common.CopyBytes(cached.Key)
+		collapsed, cached := n.copy(), n.copy()
+		collapsed.Key = compactEncode(n.Key)
+		cached.Key = common.CopyBytes(n.Key)
 
-		n.Key = compactEncode(n.Key)
 		if _, ok := n.Val.(valueNode); !ok {
-			if n.Val, cached.Val, err = h.hash(n.Val, db, false); err != nil {
-				return n, original, err
+			collapsed.Val, cached.Val, err = h.hash(n.Val, db, false)
+			if err != nil {
+				return original, original, err
 			}
 		}
-		if n.Val == nil {
-			n.Val = valueNode(nil) // Ensure that nil children are encoded as empty strings.
+		if collapsed.Val == nil {
+			collapsed.Val = valueNode(nil) // Ensure that nil children are encoded as empty strings.
 		}
-		return n, cached, nil
+		return collapsed, cached, nil
 
-	case fullNode:
+	case *fullNode:
 		// Hash the full node's children, caching the newly hashed subtrees
-		cached := fullNode{dirty: n.dirty}
+		collapsed, cached := n.copy(), n.copy()
 
 		for i := 0; i < 16; i++ {
 			if n.Children[i] != nil {
-				if n.Children[i], cached.Children[i], err = h.hash(n.Children[i], db, false); err != nil {
-					return n, original, err
+				collapsed.Children[i], cached.Children[i], err = h.hash(n.Children[i], db, false)
+				if err != nil {
+					return original, original, err
 				}
 			} else {
-				n.Children[i] = valueNode(nil) // Ensure that nil children are encoded as empty strings.
+				collapsed.Children[i] = valueNode(nil) // Ensure that nil children are encoded as empty strings.
 			}
 		}
 		cached.Children[16] = n.Children[16]
-		if n.Children[16] == nil {
-			n.Children[16] = valueNode(nil)
+		if collapsed.Children[16] == nil {
+			collapsed.Children[16] = valueNode(nil)
 		}
-		return n, cached, nil
+		return collapsed, cached, nil
 
 	default:
 		// Value and hash nodes don't have children so they're left as were
@@ -140,6 +157,7 @@ func (h *hasher) store(n node, db DatabaseWriter, force bool) (node, error) {
 	if err := rlp.Encode(h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
+
 	if h.tmp.Len() < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
diff --git a/trie/iterator.go b/trie/iterator.go
index 8cad51aff..afde6e19e 100644
--- a/trie/iterator.go
+++ b/trie/iterator.go
@@ -56,11 +56,11 @@ func (it *Iterator) makeKey() []byte {
 	key := it.keyBuf[:0]
 	for _, se := range it.nodeIt.stack {
 		switch node := se.node.(type) {
-		case fullNode:
+		case *fullNode:
 			if se.child <= 16 {
 				key = append(key, byte(se.child))
 			}
-		case shortNode:
+		case *shortNode:
 			if hasTerm(node.Key) {
 				key = append(key, node.Key[:len(node.Key)-1]...)
 			} else {
@@ -148,7 +148,7 @@ func (it *NodeIterator) step() error {
 		if (ancestor == common.Hash{}) {
 			ancestor = parent.parent
 		}
-		if node, ok := parent.node.(fullNode); ok {
+		if node, ok := parent.node.(*fullNode); ok {
 			// Full node, traverse all children, then the node itself
 			if parent.child >= len(node.Children) {
 				break
@@ -156,7 +156,7 @@ func (it *NodeIterator) step() error {
 			for parent.child++; parent.child < len(node.Children); parent.child++ {
 				if current := node.Children[parent.child]; current != nil {
 					it.stack = append(it.stack, &nodeIteratorState{
-						hash:   common.BytesToHash(node.hash),
+						hash:   common.BytesToHash(node.flags.hash),
 						node:   current,
 						parent: ancestor,
 						child:  -1,
@@ -164,14 +164,14 @@ func (it *NodeIterator) step() error {
 					break
 				}
 			}
-		} else if node, ok := parent.node.(shortNode); ok {
+		} else if node, ok := parent.node.(*shortNode); ok {
 			// Short node, traverse the pointer singleton child, then the node itself
 			if parent.child >= 0 {
 				break
 			}
 			parent.child++
 			it.stack = append(it.stack, &nodeIteratorState{
-				hash:   common.BytesToHash(node.hash),
+				hash:   common.BytesToHash(node.flags.hash),
 				node:   node.Val,
 				parent: ancestor,
 				child:  -1,
diff --git a/trie/node.go b/trie/node.go
index b97d370be..de9752c93 100644
--- a/trie/node.go
+++ b/trie/node.go
@@ -30,42 +30,60 @@ var indices = []string{"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b
 type node interface {
 	fstring(string) string
 	cache() (hashNode, bool)
+	canUnload(cachegen, cachelimit uint16) bool
 }
 
 type (
 	fullNode struct {
 		Children [17]node // Actual trie node data to encode/decode (needs custom encoder)
-		hash     hashNode // Cached hash of the node to prevent rehashing (may be nil)
-		dirty    bool     // Cached flag whether the node's new or already stored
+		flags    nodeFlag
 	}
 	shortNode struct {
 		Key   []byte
 		Val   node
-		hash  hashNode // Cached hash of the node to prevent rehashing (may be nil)
-		dirty bool     // Cached flag whether the node's new or already stored
+		flags nodeFlag
 	}
 	hashNode  []byte
 	valueNode []byte
 )
 
 // EncodeRLP encodes a full node into the consensus RLP format.
-func (n fullNode) EncodeRLP(w io.Writer) error {
+func (n *fullNode) EncodeRLP(w io.Writer) error {
 	return rlp.Encode(w, n.Children)
 }
 
-// Cache accessors to retrieve precalculated values (avoid lengthy type switches).
-func (n fullNode) cache() (hashNode, bool)  { return n.hash, n.dirty }
-func (n shortNode) cache() (hashNode, bool) { return n.hash, n.dirty }
-func (n hashNode) cache() (hashNode, bool)  { return nil, true }
-func (n valueNode) cache() (hashNode, bool) { return nil, true }
+func (n *fullNode) copy() *fullNode   { copy := *n; return &copy }
+func (n *shortNode) copy() *shortNode { copy := *n; return &copy }
+
+// nodeFlag contains caching-related metadata about a node.
+type nodeFlag struct {
+	hash  hashNode // cached hash of the node (may be nil)
+	gen   uint16   // cache generation counter
+	dirty bool     // whether the node has changes that must be written to the database
+}
+
+// canUnload tells whether a node can be unloaded.
+func (n *nodeFlag) canUnload(cachegen, cachelimit uint16) bool {
+	return !n.dirty && cachegen-n.gen >= cachelimit
+}
+
+func (n *fullNode) canUnload(gen, limit uint16) bool  { return n.flags.canUnload(gen, limit) }
+func (n *shortNode) canUnload(gen, limit uint16) bool { return n.flags.canUnload(gen, limit) }
+func (n hashNode) canUnload(uint16, uint16) bool      { return false }
+func (n valueNode) canUnload(uint16, uint16) bool     { return false }
+
+func (n *fullNode) cache() (hashNode, bool)  { return n.flags.hash, n.flags.dirty }
+func (n *shortNode) cache() (hashNode, bool) { return n.flags.hash, n.flags.dirty }
+func (n hashNode) cache() (hashNode, bool)   { return nil, true }
+func (n valueNode) cache() (hashNode, bool)  { return nil, true }
 
 // Pretty printing.
-func (n fullNode) String() string  { return n.fstring("") }
-func (n shortNode) String() string { return n.fstring("") }
-func (n hashNode) String() string  { return n.fstring("") }
-func (n valueNode) String() string { return n.fstring("") }
+func (n *fullNode) String() string  { return n.fstring("") }
+func (n *shortNode) String() string { return n.fstring("") }
+func (n hashNode) String() string   { return n.fstring("") }
+func (n valueNode) String() string  { return n.fstring("") }
 
-func (n fullNode) fstring(ind string) string {
+func (n *fullNode) fstring(ind string) string {
 	resp := fmt.Sprintf("[\n%s  ", ind)
 	for i, node := range n.Children {
 		if node == nil {
@@ -76,7 +94,7 @@ func (n fullNode) fstring(ind string) string {
 	}
 	return resp + fmt.Sprintf("\n%s] ", ind)
 }
-func (n shortNode) fstring(ind string) string {
+func (n *shortNode) fstring(ind string) string {
 	return fmt.Sprintf("{%x: %v} ", n.Key, n.Val.fstring(ind+"  "))
 }
 func (n hashNode) fstring(ind string) string {
@@ -120,6 +138,7 @@ func decodeShort(hash, buf, elems []byte) (node, error) {
 	if err != nil {
 		return nil, err
 	}
+	flag := nodeFlag{hash: hash}
 	key := compactDecode(kbuf)
 	if key[len(key)-1] == 16 {
 		// value node
@@ -127,17 +146,17 @@ func decodeShort(hash, buf, elems []byte) (node, error) {
 		if err != nil {
 			return nil, fmt.Errorf("invalid value node: %v", err)
 		}
-		return shortNode{key, valueNode(val), hash, false}, nil
+		return &shortNode{key, append(valueNode{}, val...), flag}, nil
 	}
 	r, _, err := decodeRef(rest)
 	if err != nil {
 		return nil, wrapError(err, "val")
 	}
-	return shortNode{key, r, hash, false}, nil
+	return &shortNode{key, r, flag}, nil
 }
 
-func decodeFull(hash, buf, elems []byte) (fullNode, error) {
-	n := fullNode{hash: hash}
+func decodeFull(hash, buf, elems []byte) (*fullNode, error) {
+	n := &fullNode{flags: nodeFlag{hash: hash}}
 	for i := 0; i < 16; i++ {
 		cld, rest, err := decodeRef(elems)
 		if err != nil {
@@ -150,7 +169,7 @@ func decodeFull(hash, buf, elems []byte) (fullNode, error) {
 		return n, err
 	}
 	if len(val) > 0 {
-		n.Children[16] = valueNode(val)
+		n.Children[16] = append(valueNode{}, val...)
 	}
 	return n, nil
 }
@@ -176,7 +195,7 @@ func decodeRef(buf []byte) (node, []byte, error) {
 		// empty node
 		return nil, rest, nil
 	case kind == rlp.String && len(val) == 32:
-		return hashNode(val), rest, nil
+		return append(hashNode{}, val...), rest, nil
 	default:
 		return nil, nil, fmt.Errorf("invalid RLP string size %d (want 0 or 32)", len(val))
 	}
diff --git a/trie/node_test.go b/trie/node_test.go
new file mode 100644
index 000000000..7ad1ff9e7
--- /dev/null
+++ b/trie/node_test.go
@@ -0,0 +1,58 @@
+// Copyright 2016 The go-ethereum Authors
+// This file is part of the go-ethereum library.
+//
+// The go-ethereum library is free software: you can redistribute it and/or modify
+// it under the terms of the GNU Lesser General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+//
+// The go-ethereum library is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+// GNU Lesser General Public License for more details.
+//
+// You should have received a copy of the GNU Lesser General Public License
+// along with the go-ethereum library. If not, see <http://www.gnu.org/licenses/>.
+
+package trie
+
+import "testing"
+
+func TestCanUnload(t *testing.T) {
+	tests := []struct {
+		flag                 nodeFlag
+		cachegen, cachelimit uint16
+		want                 bool
+	}{
+		{
+			flag: nodeFlag{dirty: true, gen: 0},
+			want: false,
+		},
+		{
+			flag:     nodeFlag{dirty: false, gen: 0},
+			cachegen: 0, cachelimit: 0,
+			want: true,
+		},
+		{
+			flag:     nodeFlag{dirty: false, gen: 65534},
+			cachegen: 65535, cachelimit: 1,
+			want: true,
+		},
+		{
+			flag:     nodeFlag{dirty: false, gen: 65534},
+			cachegen: 0, cachelimit: 1,
+			want: true,
+		},
+		{
+			flag:     nodeFlag{dirty: false, gen: 1},
+			cachegen: 65535, cachelimit: 1,
+			want: true,
+		},
+	}
+
+	for _, test := range tests {
+		if got := test.flag.canUnload(test.cachegen, test.cachelimit); got != test.want {
+			t.Errorf("%+v\n   got %t, want %t", test, got, test.want)
+		}
+	}
+}
diff --git a/trie/proof.go b/trie/proof.go
index 116c13a1b..f193b52df 100644
--- a/trie/proof.go
+++ b/trie/proof.go
@@ -44,7 +44,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 	tn := t.root
 	for len(key) > 0 && tn != nil {
 		switch n := tn.(type) {
-		case shortNode:
+		case *shortNode:
 			if len(key) < len(n.Key) || !bytes.Equal(n.Key, key[:len(n.Key)]) {
 				// The trie doesn't contain the key.
 				tn = nil
@@ -53,7 +53,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 				key = key[len(n.Key):]
 			}
 			nodes = append(nodes, n)
-		case fullNode:
+		case *fullNode:
 			tn = n.Children[key[0]]
 			key = key[1:]
 			nodes = append(nodes, n)
@@ -70,7 +70,7 @@ func (t *Trie) Prove(key []byte) []rlp.RawValue {
 			panic(fmt.Sprintf("%T: invalid node: %v", tn, tn))
 		}
 	}
-	hasher := newHasher()
+	hasher := newHasher(0, 0)
 	proof := make([]rlp.RawValue, 0, len(nodes))
 	for i, n := range nodes {
 		// Don't bother checking for errors here since hasher panics
@@ -130,13 +130,13 @@ func VerifyProof(rootHash common.Hash, key []byte, proof []rlp.RawValue) (value
 func get(tn node, key []byte) ([]byte, node) {
 	for len(key) > 0 {
 		switch n := tn.(type) {
-		case shortNode:
+		case *shortNode:
 			if len(key) < len(n.Key) || !bytes.Equal(n.Key, key[:len(n.Key)]) {
 				return nil, nil
 			}
 			tn = n.Val
 			key = key[len(n.Key):]
-		case fullNode:
+		case *fullNode:
 			tn = n.Children[key[0]]
 			key = key[1:]
 		case hashNode:
diff --git a/trie/secure_trie.go b/trie/secure_trie.go
index 2a8b57214..4d9ebe4d3 100644
--- a/trie/secure_trie.go
+++ b/trie/secure_trie.go
@@ -49,8 +49,12 @@ type SecureTrie struct {
 // If root is the zero hash or the sha3 hash of an empty string, the
 // trie is initially empty. Otherwise, New will panic if db is nil
 // and returns MissingNodeError if the root node cannot be found.
+//
 // Accessing the trie loads nodes from db on demand.
-func NewSecure(root common.Hash, db Database) (*SecureTrie, error) {
+// Loaded nodes are kept around until their 'cache generation' expires.
+// A new cache generation is created by each call to Commit.
+// cachelimit sets the number of past cache generations to keep.
+func NewSecure(root common.Hash, db Database, cachelimit uint16) (*SecureTrie, error) {
 	if db == nil {
 		panic("NewSecure called with nil database")
 	}
@@ -58,9 +62,8 @@ func NewSecure(root common.Hash, db Database) (*SecureTrie, error) {
 	if err != nil {
 		return nil, err
 	}
-	return &SecureTrie{
-		trie: *trie,
-	}, nil
+	trie.SetCacheLimit(cachelimit)
+	return &SecureTrie{trie: *trie}, nil
 }
 
 // Get returns the value for key stored in the trie.
@@ -191,7 +194,7 @@ func (t *SecureTrie) secKey(key []byte) []byte {
 // The caller must not hold onto the return value because it will become
 // invalid on the next call to hashKey or secKey.
 func (t *SecureTrie) hashKey(key []byte) []byte {
-	h := newHasher()
+	h := newHasher(0, 0)
 	h.sha.Reset()
 	h.sha.Write(key)
 	buf := h.sha.Sum(t.hashKeyBuf[:0])
diff --git a/trie/secure_trie_test.go b/trie/secure_trie_test.go
index 3171b8c31..159640fda 100644
--- a/trie/secure_trie_test.go
+++ b/trie/secure_trie_test.go
@@ -29,7 +29,7 @@ import (
 
 func newEmptySecure() *SecureTrie {
 	db, _ := ethdb.NewMemDatabase()
-	trie, _ := NewSecure(common.Hash{}, db)
+	trie, _ := NewSecure(common.Hash{}, db, 0)
 	return trie
 }
 
@@ -37,7 +37,7 @@ func newEmptySecure() *SecureTrie {
 func makeTestSecureTrie() (ethdb.Database, *SecureTrie, map[string][]byte) {
 	// Create an empty trie
 	db, _ := ethdb.NewMemDatabase()
-	trie, _ := NewSecure(common.Hash{}, db)
+	trie, _ := NewSecure(common.Hash{}, db, 0)
 
 	// Fill it with some arbitrary data
 	content := make(map[string][]byte)
diff --git a/trie/sync.go b/trie/sync.go
index 6e9e029b9..3de758536 100644
--- a/trie/sync.go
+++ b/trie/sync.go
@@ -212,12 +212,12 @@ func (s *TrieSync) children(req *request) ([]*request, error) {
 	children := []child{}
 
 	switch node := (*req.object).(type) {
-	case shortNode:
+	case *shortNode:
 		children = []child{{
 			node:  &node.Val,
 			depth: req.depth + len(node.Key),
 		}}
-	case fullNode:
+	case *fullNode:
 		for i := 0; i < 17; i++ {
 			if node.Children[i] != nil {
 				children = append(children, child{
diff --git a/trie/trie.go b/trie/trie.go
index 55598af98..65005bae8 100644
--- a/trie/trie.go
+++ b/trie/trie.go
@@ -62,6 +62,23 @@ type Trie struct {
 	root         node
 	db           Database
 	originalRoot common.Hash
+
+	// Cache generation values.
