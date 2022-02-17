commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
commit e8ea5aa0d59a722df616bc8c8cffacadd23c082d
Author: Felix Lange <fjl@twurst.com>
Date:   Tue Jun 5 14:06:29 2018 +0200

    trie: reduce hasher allocations (#16896)
    
    * trie: reduce hasher allocations
    
    name    old time/op    new time/op    delta
    Hash-8    4.05µs ±12%    3.56µs ± 9%  -12.13%  (p=0.000 n=20+19)
    
    name    old alloc/op   new alloc/op   delta
    Hash-8    1.30kB ± 0%    0.66kB ± 0%  -49.15%  (p=0.000 n=20+20)
    
    name    old allocs/op  new allocs/op  delta
    Hash-8      11.0 ± 0%       8.0 ± 0%  -27.27%  (p=0.000 n=20+20)
    
    * trie: bump initial buffer cap in hasher

diff --git a/trie/hasher.go b/trie/hasher.go
index ff61e7092..47c6dd8f9 100644
--- a/trie/hasher.go
+++ b/trie/hasher.go
@@ -17,7 +17,6 @@
 package trie
 
 import (
-	"bytes"
 	"hash"
 	"sync"
 
@@ -27,17 +26,39 @@ import (
 )
 
 type hasher struct {
-	tmp        *bytes.Buffer
-	sha        hash.Hash
+	tmp        sliceBuffer
+	sha        keccakState
 	cachegen   uint16
 	cachelimit uint16
 	onleaf     LeafCallback
 }
 
+// keccakState wraps sha3.state. In addition to the usual hash methods, it also supports
+// Read to get a variable amount of data from the hash state. Read is faster than Sum
+// because it doesn't copy the internal state, but also modifies the internal state.
+type keccakState interface {
+	hash.Hash
+	Read([]byte) (int, error)
+}
+
+type sliceBuffer []byte
+
+func (b *sliceBuffer) Write(data []byte) (n int, err error) {
+	*b = append(*b, data...)
+	return len(data), nil
+}
+
+func (b *sliceBuffer) Reset() {
+	*b = (*b)[:0]
+}
+
 // hashers live in a global db.
 var hasherPool = sync.Pool{
 	New: func() interface{} {
-		return &hasher{tmp: new(bytes.Buffer), sha: sha3.NewKeccak256()}
+		return &hasher{
+			tmp: make(sliceBuffer, 0, 550), // cap is as large as a full fullNode.
+			sha: sha3.NewKeccak256().(keccakState),
+		}
 	},
 }
 
@@ -157,26 +178,23 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	// Generate the RLP encoding of the node
 	h.tmp.Reset()
-	if err := rlp.Encode(h.tmp, n); err != nil {
+	if err := rlp.Encode(&h.tmp, n); err != nil {
 		panic("encode error: " + err.Error())
 	}
-	if h.tmp.Len() < 32 && !force {
+	if len(h.tmp) < 32 && !force {
 		return n, nil // Nodes smaller than 32 bytes are stored inside their parent
 	}
 	// Larger nodes are replaced by their hash and stored in the database.
 	hash, _ := n.cache()
 	if hash == nil {
-		h.sha.Reset()
-		h.sha.Write(h.tmp.Bytes())
-		hash = hashNode(h.sha.Sum(nil))
+		hash = h.makeHashNode(h.tmp)
 	}
+
 	if db != nil {
 		// We are pooling the trie nodes into an intermediate memory cache
 		db.lock.Lock()
-
 		hash := common.BytesToHash(hash)
-		db.insert(hash, h.tmp.Bytes())
-
+		db.insert(hash, h.tmp)
 		// Track all direct parent->child node references
 		switch n := n.(type) {
 		case *shortNode:
@@ -210,3 +228,11 @@ func (h *hasher) store(n node, db *Database, force bool) (node, error) {
 	}
 	return hash, nil
 }
+
+func (h *hasher) makeHashNode(data []byte) hashNode {
+	n := make(hashNode, h.sha.Size())
+	h.sha.Reset()
+	h.sha.Write(data)
+	h.sha.Read(n)
+	return n
+}
