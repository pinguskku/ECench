commit 855e76fddd8c5f0e024a536c0466f7578fcb592d
Author: Jeffrey Wilcke <jeffrey@ethereum.org>
Date:   Fri Jun 19 18:16:09 2015 +0200

    core: reduced cache limit to 256

diff --git a/core/chain_manager.go b/core/chain_manager.go
index e67439bb6..3adaf3344 100644
--- a/core/chain_manager.go
+++ b/core/chain_manager.go
@@ -36,7 +36,7 @@ var (
 )
 
 const (
-	blockCacheLimit     = 10000
+	blockCacheLimit     = 256
 	maxFutureBlocks     = 256
 	maxTimeFutureBlocks = 30
 )
