commit 580bae0a86ab39662dc49efe008424518469cafd
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Fri May 15 00:40:07 2015 +0200

    core: improved uncle messages

diff --git a/core/block_processor.go b/core/block_processor.go
index 059c442cc..5199e4b4d 100644
--- a/core/block_processor.go
+++ b/core/block_processor.go
@@ -347,17 +347,17 @@ func (sm *BlockProcessor) VerifyUncles(statedb *state.StateDB, block, parent *ty
 	for i, uncle := range block.Uncles() {
 		if uncles.Has(uncle.Hash()) {
 			// Error not unique
-			return UncleError("Uncle not unique")
+			return UncleError("uncle[%d] not unique", i)
 		}
 
 		uncles.Add(uncle.Hash())
 
 		if ancestors.Has(uncle.Hash()) {
-			return UncleError("Uncle is ancestor")
+			return UncleError("uncle[%d] is ancestor", i)
 		}
 
 		if !ancestors.Has(uncle.ParentHash) {
-			return UncleError(fmt.Sprintf("Uncle's parent unknown (%x)", uncle.ParentHash[0:4]))
+			return UncleError("uncle[%d]'s parent unknown (%x)", i, uncle.ParentHash[0:4])
 		}
 
 		if err := sm.ValidateHeader(uncle, ancestorHeaders[uncle.ParentHash]); err != nil {
