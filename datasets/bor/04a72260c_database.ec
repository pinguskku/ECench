commit 04a72260c5bcca0ec7c4a63532fb29f68db03384
Author: Melvin Junhee Woo <melvin.woo@groundx.xyz>
Date:   Mon Jan 25 22:25:55 2021 +0900

    snapshot: merge loops for better performance (#22160)

diff --git a/core/state/snapshot/difflayer.go b/core/state/snapshot/difflayer.go
index cc82df9a5..9c86a679d 100644
--- a/core/state/snapshot/difflayer.go
+++ b/core/state/snapshot/difflayer.go
@@ -191,19 +191,15 @@ func newDiffLayer(parent snapshot, root common.Hash, destructs map[common.Hash]s
 		if blob == nil {
 			panic(fmt.Sprintf("account %#x nil", accountHash))
 		}
+		// Determine memory size and track the dirty writes
+		dl.memory += uint64(common.HashLength + len(blob))
+		snapshotDirtyAccountWriteMeter.Mark(int64(len(blob)))
 	}
 	for accountHash, slots := range storage {
 		if slots == nil {
 			panic(fmt.Sprintf("storage %#x nil", accountHash))
 		}
-	}
-	// Determine memory size and track the dirty writes
-	for _, data := range accounts {
-		dl.memory += uint64(common.HashLength + len(data))
-		snapshotDirtyAccountWriteMeter.Mark(int64(len(data)))
-	}
-	// Determine memory size and track the dirty writes
-	for _, slots := range storage {
+		// Determine memory size and track the dirty writes
 		for _, data := range slots {
 			dl.memory += uint64(common.HashLength + len(data))
 			snapshotDirtyStorageWriteMeter.Mark(int64(len(data)))
