commit 207bd5575161fa2bc61a7ccf659c11878575dd32
Author: obscuren <geffobscura@gmail.com>
Date:   Thu May 21 11:45:35 2015 +0200

    eth: reduced max open files for LevelDB

diff --git a/eth/backend.go b/eth/backend.go
index 44ceb89e8..69504fd94 100644
--- a/eth/backend.go
+++ b/eth/backend.go
@@ -213,7 +213,7 @@ func New(config *Config) (*Ethereum, error) {
 
 	// Let the database take 3/4 of the max open files (TODO figure out a way to get the actual limit of the open files)
 	const dbCount = 3
-	ethdb.OpenFileLimit = 256 / (dbCount + 1)
+	ethdb.OpenFileLimit = 128 / (dbCount + 1)
 
 	newdb := config.NewDB
 	if newdb == nil {
