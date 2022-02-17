commit d0d6d900efab2c0854855307e2e27b111e4500aa
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Fri Aug 24 16:14:52 2018 +0100

    unnecessary

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index accf12b37..99ab71e6b 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -326,11 +326,6 @@ namespace Nethermind.Blockchain
                 {
                     if (_logger.IsError) _logger.Error($"Error during sync process: {t.Exception}");
                 }
-
-                if (_logger.IsInfo)
-                {
-                    _logger.Info($"Sync process finished, [{(t.IsFaulted ? "FAULTED" : t.IsCanceled ? "CANCELLED" : t.IsCompleted ? "COMPLETED" : "OTHER")}]");
-                }
                 
                 lock (_isSyncingLock)
                 {
