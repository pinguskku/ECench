commit 22f4d585cec4b1cb649c4dfe4d7b75c5d20de1b4
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Mon Mar 23 22:43:04 2020 +0000

    removed minor memory leak in discovery (#1578)

diff --git a/src/Nethermind/Nethermind.Network/Discovery/DiscoveryManager.cs b/src/Nethermind/Nethermind.Network/Discovery/DiscoveryManager.cs
index 58ab84548..7ecc73f4a 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/DiscoveryManager.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/DiscoveryManager.cs
@@ -178,6 +178,10 @@ namespace Nethermind.Network.Discovery
             {
                 delayCancellation.Cancel();
             }
+            else
+            {
+                RemoveCompletionSource(senderIdHash, (int)messageType);
+            }
             
             return result;
         }
