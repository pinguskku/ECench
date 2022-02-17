commit df0d538bdf25d3ddb4ba9c5c2ada77069dfc286e
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Mon Mar 18 14:10:47 2019 +0000

    Now -> UtcNow (performance)

diff --git a/src/Nethermind/Nethermind.Stats/NodeStatsLight.cs b/src/Nethermind/Nethermind.Stats/NodeStatsLight.cs
index 1b3ebe8d4..c0dd03fdf 100644
--- a/src/Nethermind/Nethermind.Stats/NodeStatsLight.cs
+++ b/src/Nethermind/Nethermind.Stats/NodeStatsLight.cs
@@ -19,7 +19,6 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
-using Nethermind.Core.Logging;
 using Nethermind.Stats.Model;
 
 namespace Nethermind.Stats
@@ -43,7 +42,7 @@ namespace Nethermind.Stats
 
         private DisconnectReason? _lastLocalDisconnect;
         private DisconnectReason? _lastRemoteDisconnect;
-                
+
         private DateTime? _lastDisconnectTime;
         private DateTime? _lastFailedConnectionTime;
         private static readonly Random Random = new Random();
@@ -88,7 +87,7 @@ namespace Nethermind.Stats
         {
             if (nodeStatsEventType == NodeStatsEventType.ConnectionFailed)
             {
-                _lastFailedConnectionTime = DateTime.Now;
+                _lastFailedConnectionTime = DateTime.UtcNow;
             }
 
             Increment(nodeStatsEventType);
@@ -101,7 +100,7 @@ namespace Nethermind.Stats
 
         public void AddNodeStatsDisconnectEvent(DisconnectType disconnectType, DisconnectReason disconnectReason)
         {
-            _lastDisconnectTime = DateTime.Now;
+            _lastDisconnectTime = DateTime.UtcNow;
             if (disconnectType == DisconnectType.Local)
             {
                 _lastLocalDisconnect = disconnectReason;
@@ -197,7 +196,7 @@ namespace Nethermind.Stats
                 return false;
             }
 
-            var timePassed = DateTime.Now.Subtract(_lastDisconnectTime.Value).TotalMilliseconds;
+            var timePassed = DateTime.UtcNow.Subtract(_lastDisconnectTime.Value).TotalMilliseconds;
             var disconnectDelay = GetDisconnectDelay();
             if (disconnectDelay <= 500)
             {
@@ -221,7 +220,7 @@ namespace Nethermind.Stats
                 return false;
             }
 
-            var timePassed = DateTime.Now.Subtract(_lastFailedConnectionTime.Value).TotalMilliseconds;
+            var timePassed = DateTime.UtcNow.Subtract(_lastFailedConnectionTime.Value).TotalMilliseconds;
             var failedConnectionDelay = GetFailedConnectionDelay();
             var result = timePassed < failedConnectionDelay;
 
@@ -360,7 +359,7 @@ namespace Nethermind.Stats
             {
                 if (_lastRemoteDisconnect == DisconnectReason.TooManyPeers || _lastRemoteDisconnect == DisconnectReason.AlreadyConnected)
                 {
-                    var timeFromLastDisconnect = DateTime.Now.Subtract(_lastDisconnectTime ?? DateTime.MinValue).TotalMilliseconds;
+                    var timeFromLastDisconnect = DateTime.UtcNow.Subtract(_lastDisconnectTime ?? DateTime.MinValue).TotalMilliseconds;
                     return timeFromLastDisconnect < _statsConfig.PenalizedReputationTooManyPeersTimeout;
                 }
 
