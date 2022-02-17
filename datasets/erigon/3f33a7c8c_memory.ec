commit 3f33a7c8ceeefd769a68bbcc2ed3e4ce74ddaef8
Author: Felix Lange <fjl@users.noreply.github.com>
Date:   Mon Jun 4 09:32:32 2018 +0200

    consensus/ethash: reduce keccak hash allocations (#16857)
    
    Use Read instead of Sum to avoid internal allocations and
    copying the state.
    
    name                      old time/op  new time/op  delta
    CacheGeneration-8          764ms ± 1%   579ms ± 1%  -24.22%  (p=0.000 n=20+17)
    SmallDatasetGeneration-8  75.2ms ±12%  60.6ms ±10%  -19.37%  (p=0.000 n=20+20)
    HashimotoLight-8          1.58ms ±11%  1.55ms ± 8%     ~     (p=0.322 n=20+19)
    HashimotoFullSmall-8      4.90µs ± 1%  4.88µs ± 1%   -0.31%  (p=0.013 n=19+18)

diff --git a/consensus/ethash/algorithm.go b/consensus/ethash/algorithm.go
index 905a7b1ea..fa1c2c824 100644
--- a/consensus/ethash/algorithm.go
+++ b/consensus/ethash/algorithm.go
@@ -94,14 +94,25 @@ func calcDatasetSize(epoch int) uint64 {
 // reused between hash runs instead of requiring new ones to be created.
 type hasher func(dest []byte, data []byte)
 
-// makeHasher creates a repetitive hasher, allowing the same hash data structures
-// to be reused between hash runs instead of requiring new ones to be created.
-// The returned function is not thread safe!
+// makeHasher creates a repetitive hasher, allowing the same hash data structures to
+// be reused between hash runs instead of requiring new ones to be created. The returned
+// function is not thread safe!
 func makeHasher(h hash.Hash) hasher {
+	// sha3.state supports Read to get the sum, use it to avoid the overhead of Sum.
+	// Read alters the state but we reset the hash before every operation.
+	type readerHash interface {
+		hash.Hash
+		Read([]byte) (int, error)
+	}
+	rh, ok := h.(readerHash)
+	if !ok {
+		panic("can't find Read method on hash")
+	}
+	outputLen := rh.Size()
 	return func(dest []byte, data []byte) {
-		h.Write(data)
-		h.Sum(dest[:0])
-		h.Reset()
+		rh.Reset()
+		rh.Write(data)
+		rh.Read(dest[:outputLen])
 	}
 }
 
