commit 14bef9a2dba1f6370c694779962e742e9853fdc6
Author: Péter Szilágyi <peterke@gmail.com>
Date:   Wed Oct 3 13:42:19 2018 +0300

    core: fix unnecessary ancestor lookup after a fast sync (#17825)

diff --git a/core/chain_indexer.go b/core/chain_indexer.go
index 4bdd4ba1c..28dc47668 100644
--- a/core/chain_indexer.go
+++ b/core/chain_indexer.go
@@ -219,13 +219,13 @@ func (c *ChainIndexer) eventLoop(currentHeader *types.Header, events chan ChainE
 			}
 			header := ev.Block.Header()
 			if header.ParentHash != prevHash {
-				// Reorg to the common ancestor (might not exist in light sync mode, skip reorg then)
+				// Reorg to the common ancestor if needed (might not exist in light sync mode, skip reorg then)
 				// TODO(karalabe, zsfelfoldi): This seems a bit brittle, can we detect this case explicitly?
 
-				// TODO(karalabe): This operation is expensive and might block, causing the event system to
-				// potentially also lock up. We need to do with on a different thread somehow.
-				if h := rawdb.FindCommonAncestor(c.chainDb, prevHeader, header); h != nil {
-					c.newHead(h.Number.Uint64(), true)
+				if rawdb.ReadCanonicalHash(c.chainDb, prevHeader.Number.Uint64()) != prevHash {
+					if h := rawdb.FindCommonAncestor(c.chainDb, prevHeader, header); h != nil {
+						c.newHead(h.Number.Uint64(), true)
+					}
 				}
 			}
 			c.newHead(header.Number.Uint64(), false)
