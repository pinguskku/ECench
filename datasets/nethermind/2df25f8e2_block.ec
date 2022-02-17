commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
commit 2df25f8e2cfc63da2c9ba73732fb64f19453fb7e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Dec 16 02:24:41 2019 +0000

    selector improvements for cases when we encounter a node synced up to below 32

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
index 2d20b69e5..b7dabf85d 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/SyncModeSelectorTests.cs
@@ -102,7 +102,8 @@ namespace Nethermind.Blockchain.Test.Synchronization
         [TestCase(true, 1032, 1000, 0, 0, SyncMode.StateNodes)]
         [TestCase(true, 1032, 1000, 0, 1000, SyncMode.Full)]
         [TestCase(true, 0, 1032, 0, 1032, SyncMode.NotStarted)]
-        [TestCase(true, 1, 1032, 0, 1032, SyncMode.Full)]
+        [TestCase(true, 1, 1032, 0, 1032, SyncMode.NotStarted)]
+        [TestCase(true, 33, 1032, 0, 1032, SyncMode.NotStarted)]
         [TestCase(false, 0, 1032, 0, 1032, SyncMode.Full)]
         [TestCase(true, 4506571, 4506571, 4506571, 4506452, SyncMode.Full)]
         public void Selects_correctly(bool useFastSync, long bestRemote, long bestHeader, long bestBlock, long bestLocalState, SyncMode expected)
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
index f16e299ce..86f21e2e3 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/SyncModeSelector.cs
@@ -83,19 +83,25 @@ namespace Nethermind.Blockchain.Synchronization
                     maxBlockNumberAmongPeers = Math.Max(maxBlockNumberAmongPeers, peerInfo.HeadNumber);
                 }
 
-                if (maxBlockNumberAmongPeers == 0)
+                if (maxBlockNumberAmongPeers <= FullSyncThreshold)
                 {
                     return;
                 }
 
                 SyncMode newSyncMode;
+                long bestFull = Math.Max(bestFullState, bestFullBlock);
                 if (!_syncProgressResolver.IsFastBlocksFinished())
                 {
                     newSyncMode = SyncMode.FastBlocks;
                 }
-                else if (maxBlockNumberAmongPeers - Math.Max(bestFullState, bestFullBlock) <= FullSyncThreshold)
+                else if (maxBlockNumberAmongPeers - bestFull  <= FullSyncThreshold)
                 {
-                    newSyncMode = Math.Max(bestFullState, bestFullBlock) >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
+                    if (maxBlockNumberAmongPeers < bestFull)
+                    {
+                        return;
+                    }
+                    
+                    newSyncMode = bestFull >= bestHeader ? SyncMode.Full : SyncMode.StateNodes;
                 }
                 else if (maxBlockNumberAmongPeers - bestHeader <= FullSyncThreshold)
                 {
