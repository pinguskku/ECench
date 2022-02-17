commit ea06da089264508601a9f967160b8c7f335071fa
Author: Sarlor <kinsleer@outlook.com>
Date:   Thu Jun 7 16:48:36 2018 +0800

    trie: avoid unnecessary slicing on shortnode decoding (#16917)
    
    optimization code

diff --git a/trie/encoding.go b/trie/encoding.go
index 221fa6d3a..5f120de63 100644
--- a/trie/encoding.go
+++ b/trie/encoding.go
@@ -53,10 +53,9 @@ func hexToCompact(hex []byte) []byte {
 
 func compactToHex(compact []byte) []byte {
 	base := keybytesToHex(compact)
-	base = base[:len(base)-1]
-	// apply terminator flag
-	if base[0] >= 2 {
-		base = append(base, 16)
+	// delete terminator flag
+	if base[0] < 2 {
+		base = base[:len(base)-1]
 	}
 	// apply odd flag
 	chop := 2 - base[0]&1
