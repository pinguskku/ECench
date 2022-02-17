commit e868adde30eee9001e60bcf17e5c4bec83b36090
Author: Martin Holst Swende <martin@swende.se>
Date:   Mon May 25 16:12:48 2020 +0200

    core/vm: improve jumpdest lookup (#21123)

diff --git a/core/vm/contract.go b/core/vm/contract.go
index 375e24bc1..7cee5634b 100644
--- a/core/vm/contract.go
+++ b/core/vm/contract.go
@@ -92,25 +92,28 @@ func (c *Contract) validJumpdest(dest *big.Int) bool {
 	if OpCode(c.Code[udest]) != JUMPDEST {
 		return false
 	}
-	// Do we have a contract hash already?
+	// Do we have it locally already?
+	if c.analysis != nil {
+		return c.analysis.codeSegment(udest)
+	}
+	// If we have the code hash (but no analysis), we should look into the
+	// parent analysis map and see if the analysis has been made previously
 	if c.CodeHash != (common.Hash{}) {
-		// Does parent context have the analysis?
 		analysis, exist := c.jumpdests[c.CodeHash]
 		if !exist {
 			// Do the analysis and save in parent context
-			// We do not need to store it in c.analysis
 			analysis = codeBitmap(c.Code)
 			c.jumpdests[c.CodeHash] = analysis
 		}
+		// Also stash it in current contract for faster access
+		c.analysis = analysis
 		return analysis.codeSegment(udest)
 	}
 	// We don't have the code hash, most likely a piece of initcode not already
 	// in state trie. In that case, we do an analysis, and save it locally, so
 	// we don't have to recalculate it for every JUMP instruction in the execution
 	// However, we don't save it within the parent context
-	if c.analysis == nil {
-		c.analysis = codeBitmap(c.Code)
-	}
+	c.analysis = codeBitmap(c.Code)
 	return c.analysis.codeSegment(udest)
 }
 
