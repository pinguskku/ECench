commit 8fe47b0a0d4280020c246fee817a87e358f868f3
Author: Marius van der Wijden <m.vanderwijden@live.de>
Date:   Mon Jul 12 21:34:20 2021 +0200

    core/state: avoid unnecessary alloc in trie prefetcher (#23198)

diff --git a/core/state/trie_prefetcher.go b/core/state/trie_prefetcher.go
index ac5e95c5c..25c3730e3 100644
--- a/core/state/trie_prefetcher.go
+++ b/core/state/trie_prefetcher.go
@@ -312,12 +312,11 @@ func (sf *subfetcher) loop() {
 
 				default:
 					// No termination request yet, prefetch the next entry
-					taskid := string(task)
-					if _, ok := sf.seen[taskid]; ok {
+					if _, ok := sf.seen[string(task)]; ok {
 						sf.dups++
 					} else {
 						sf.trie.TryGet(task)
-						sf.seen[taskid] = struct{}{}
+						sf.seen[string(task)] = struct{}{}
 					}
 				}
 			}
