commit 2a4a7418caeb614a472de3f8f10d528614d6bfcf
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Oct 29 18:30:54 2018 +0000

    removing unnecessary block download verbosity for now

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index b70bacc80..e39eba2bd 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -819,10 +819,10 @@ namespace Nethermind.Blockchain
 
                 peerInfo.NumberReceived = blocks[blocks.Length - 1].Number;
                 bestNumber = _blockTree.BestKnownNumber;
-                if (bestNumber > _lastSyncNumber + 1000)
+                if (bestNumber > _lastSyncNumber + 10000)
                 {
                     _lastSyncNumber = bestNumber;
-                    if (_logger.IsInfo) _logger.Info($"Downloading blocks. Current best at {_blockTree.BestKnownNumber}");
+                    if (_logger.IsDebug) _logger.Debug($"Downloading blocks. Current best at {_blockTree.BestKnownNumber}");
                 }
             }
 
