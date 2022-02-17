commit 27a3af8bca9391f63d04f105bb82ce54564e7517
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jun 16 20:13:44 2018 -0400

    Added ping timer and disconnect on missing too many pings, logging improvements

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index d9b9f5c62..d77b1023e 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -264,10 +264,6 @@ namespace Nethermind.Blockchain
                     }
                     _syncCancellationTokenSource?.Cancel();                    
                 }
-                else
-                {
-                    _logger.Info($"TESTTEST: NO");
-                }
             }
 
             if (_initCancellationTokenSources.TryGetValue(synchronizationPeer.NodeId, out var tokenSource))
diff --git a/src/Nethermind/Nethermind.Network/Discovery/DiscoveryConfigurationProvider.cs b/src/Nethermind/Nethermind.Network/Discovery/DiscoveryConfigurationProvider.cs
index 003b5a0a5..55fd56c34 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/DiscoveryConfigurationProvider.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/DiscoveryConfigurationProvider.cs
@@ -91,5 +91,7 @@ namespace Nethermind.Network.Discovery
         public int ActivePeersMaxCount { get; set; }
         public int DisconnectDelay => 1000 * 5;
         public int PeersPersistanceInterval => 1000 * 60 * 5;
+        public int P2PPingInterval => 1000 * 10;
+        public int P2PPingRetryCount => 3;
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/IDiscoveryConfigurationProvider.cs b/src/Nethermind/Nethermind.Network/Discovery/IDiscoveryConfigurationProvider.cs
index a0e998876..804a4df59 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/IDiscoveryConfigurationProvider.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/IDiscoveryConfigurationProvider.cs
@@ -207,5 +207,15 @@ namespace Nethermind.Network.Discovery
         /// Time between persisting peers in miliseconds
         /// </summary>
         int PeersPersistanceInterval { get; }
+
+        /// <summary>
+        /// Time between sending p2p ping
+        /// </summary>
+        int P2PPingInterval { get; }
+
+        /// <summary>
+        /// Number of ping missed for disconnection
+        /// </summary>
+        int P2PPingRetryCount { get; }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/P2P/IP2PMessageSender.cs b/src/Nethermind/Nethermind.Network/P2P/IP2PMessageSender.cs
new file mode 100644
index 000000000..adabf80ae
--- /dev/null
+++ b/src/Nethermind/Nethermind.Network/P2P/IP2PMessageSender.cs
@@ -0,0 +1,9 @@
+﻿using System.Threading.Tasks;
+
+namespace Nethermind.Network.P2P
+{
+    public interface IP2PMessageSender
+    {
+        Task<bool> SendPing();
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 665aa9b89..b66f87f36 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -61,9 +61,9 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled)
+            if (_logger.IsDebugEnabled)
             {
-                _logger.Error($"{nameof(NettyP2PHandler)} exception", exception);
+                _logger.Debug($"{GetType().Name} exception: {exception}");
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/P2PProtocolHandler.cs
index fdb5c6891..d2fb4080e 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PProtocolHandler.cs
@@ -21,15 +21,18 @@ using System.Collections.Generic;
 using System.Diagnostics;
 using System.Linq;
 using System.Threading.Tasks;
+using DotNetty.Common.Concurrency;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Network.Rlpx;
 
 namespace Nethermind.Network.P2P
 {
-    public class P2PProtocolHandler : ProtocolHandlerBase, IProtocolHandler
+    public class P2PProtocolHandler : ProtocolHandlerBase, IProtocolHandler, IP2PMessageSender
     {
         private bool _sentHello;
+        private bool _isInitialized;
+        private TaskCompletionSource<Packet> _pongCompletionSource;
 
         public P2PProtocolHandler(
             IP2PSession p2PSession,
@@ -93,7 +96,7 @@ namespace Nethermind.Network.P2P
             else if (msg.PacketType == P2PMessageCode.Pong)
             {
                 if(Logger.IsDebugEnabled) Logger.Debug($"{P2PSession.RemoteNodeId} Received PONG on {P2PSession.RemotePort}");
-                HandlePong();
+                HandlePong(msg);
             }
             else
             {
@@ -109,8 +112,8 @@ namespace Nethermind.Network.P2P
                 throw new NodeDetailsMismatchException();
             }
 
-            P2PSession.RemoteNodeId = hello.NodeId;
-            P2PSession.RemotePort = hello.ListenPort;
+            //P2PSession.RemoteNodeId = hello.NodeId;
+            //P2PSession.RemotePort = hello.ListenPort;
             RemoteClientId = hello.ClientId;
 
             Logger.Info(!_sentHello
@@ -160,9 +163,40 @@ namespace Nethermind.Network.P2P
                 ClientId = hello.ClientId,
                 Capabilities = hello.Capabilities
             };
+            _isInitialized = true;
             ProtocolInitialized?.Invoke(this, eventArgs);
         }
 
+        public async Task<bool> SendPing()
+        {
+            if (!_isInitialized)
+            {
+                return true;
+            }
+            if (_pongCompletionSource != null)
+            {
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Another ping request in process: {P2PSession.RemoteNodeId}");
+                    return true;
+                }
+            }
+            
+            _pongCompletionSource = new TaskCompletionSource<Packet>();
+            var pongTask = _pongCompletionSource.Task;
+
+            if (Logger.IsTraceEnabled)
+            {
+                Logger.Trace($"{P2PSession.RemoteNodeId} P2P sending ping on {P2PSession.RemotePort} ({RemoteClientId})");
+            }
+            Send(PingMessage.Instance);
+            
+            var firstTask = await Task.WhenAny(pongTask, Task.Delay(Timeouts.P2PPing));
+            _pongCompletionSource = null;
+
+            return firstTask == pongTask;
+        }
+
         private static readonly List<Capability> SupportedCapabilities = new List<Capability>
         {
             new Capability(Protocol.Eth, 62),
@@ -204,16 +238,10 @@ namespace Nethermind.Network.P2P
             P2PSession.DisconnectAsync((DisconnectReason) disconnectReason, DisconnectType.Remote);
         }
 
-        private void HandlePong()
+        private void HandlePong(Packet msg)
         {
             if(Logger.IsTraceEnabled) Logger.Trace($"{P2PSession.RemoteNodeId} P2P pong on {P2PSession.RemotePort} ({RemoteClientId})");
-        }
-
-        private void Ping()
-        {
-            if(Logger.IsTraceEnabled) Logger.Trace($"{P2PSession.RemoteNodeId} P2P sending ping on {P2PSession.RemotePort} ({RemoteClientId})");
-            // TODO: timers
-            Send(PingMessage.Instance);
+            _pongCompletionSource?.SetResult(msg);
         }
 
         public event EventHandler<ProtocolInitializedEventArgs> ProtocolInitialized;
diff --git a/src/Nethermind/Nethermind.Network/Peer.cs b/src/Nethermind/Nethermind.Network/Peer.cs
index 32be4cef5..a7f73b5f0 100644
--- a/src/Nethermind/Nethermind.Network/Peer.cs
+++ b/src/Nethermind/Nethermind.Network/Peer.cs
@@ -45,6 +45,7 @@ namespace Nethermind.Network
         public INodeStats NodeStats { get; }
         public IP2PSession Session { get; set; }
         public ISynchronizationPeer SynchronizationPeer { get; set; }
+        public IP2PMessageSender P2PMessageSender { get; set; }
         public ClientConnectionType ClientConnectionType { get; set; }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 565a28895..26196f916 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -48,6 +48,7 @@ namespace Nethermind.Network
         private readonly INodeFactory _nodeFactory;
         private Timer _activePeersTimer;
         private Timer _peerPersistanceTimer;
+        private Timer _pingTimer;
         private readonly bool _isDiscoveryEnabled;
         private int _logCounter = 1;
         private bool _isInitialized = false;
@@ -102,7 +103,10 @@ namespace Nethermind.Network
             //Step 4 - start peer persistance timer
             StartPeerPersistanceTimer();
 
-            //Step 5 - Running initial peer update
+            //Step 5 - start ping timer
+            StartPingTimer();
+
+            //Step 6 - Running initial peer update
             await RunPeerUpdate();
 
             _isInitialized = true;
@@ -116,6 +120,7 @@ namespace Nethermind.Network
             }
 
             StopPeerPersistanceTimer();
+            StopPingTimer();
 
             return Task.CompletedTask;
         }
@@ -358,7 +363,7 @@ namespace Nethermind.Network
             var session = (IP2PSession)sender;
             if (session.ClientConnectionType == ClientConnectionType.In && e.ProtocolHandler is P2PProtocolHandler)
             {
-                if (!await ProcessIncomingConnection(session))
+                if (!await ProcessIncomingConnection(session, (P2PProtocolHandler)e.ProtocolHandler))
                 {
                     return;
                 }
@@ -375,7 +380,7 @@ namespace Nethermind.Network
 
             switch (e.ProtocolHandler)
             {
-                case P2PProtocolHandler _:
+                case P2PProtocolHandler p2PProtocolHandler:
                     peer.NodeStats.NodeDetails.ClientId = ((P2PProtocolInitializedEventArgs)e).ClientId;
                     var result = await ValidateProtocol(Protocol.P2P, peer, e);
                     if (!result)
@@ -383,6 +388,7 @@ namespace Nethermind.Network
                         return;
                     }
                     peer.NodeStats.AddNodeStatsEvent(NodeStatsEvent.P2PInitialized);
+                    peer.P2PMessageSender = p2PProtocolHandler;
                     break;
                 case Eth62ProtocolHandler ethProtocolhandler:
                     result = await ValidateProtocol(Protocol.Eth, peer, e);
@@ -409,7 +415,7 @@ namespace Nethermind.Network
             }            
         }
 
-        private async Task<bool> ProcessIncomingConnection(IP2PSession session)
+        private async Task<bool> ProcessIncomingConnection(IP2PSession session, P2PProtocolHandler protocolHandler)
         {
             //if we have already initiated connection before
             if (_activePeers.ContainsKey(session.RemoteNodeId))
@@ -437,6 +443,7 @@ namespace Nethermind.Network
             if (_candidatePeers.TryGetValue(session.RemoteNodeId, out var peer))
             {
                 peer.Session = session;
+                peer.P2PMessageSender = protocolHandler;
                 peer.ClientConnectionType = session.ClientConnectionType;
             }
             else
@@ -444,8 +451,9 @@ namespace Nethermind.Network
                 peer = new Peer(_nodeFactory.CreateNode(session.RemoteNodeId, session.RemoteHost, session.RemotePort ?? 0), _nodeStatsProvider.GetNodeStats(session.RemoteNodeId))
                 {
                     ClientConnectionType = session.ClientConnectionType,
-                    Session = session
-                };
+                    Session = session,
+                    P2PMessageSender = protocolHandler
+            };
             }
 
             if (_activePeers.TryAdd(session.RemoteNodeId, peer))
@@ -662,6 +670,40 @@ namespace Nethermind.Network
             }
         }
 
+        private void StartPingTimer()
+        {
+            if (_logger.IsInfoEnabled)
+            {
+                _logger.Info("Starting ping timer");
+            }
+
+            _pingTimer = new Timer(_configurationProvider.P2PPingInterval) { AutoReset = false };
+            _pingTimer.Elapsed += async (sender, e) =>
+            {
+                _pingTimer.Enabled = false;
+                await SendPingMessages();
+                _pingTimer.Enabled = true;
+            };
+
+            _pingTimer.Start();
+        }
+
+        private void StopPingTimer()
+        {
+            try
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info("Stopping ping timer");
+                }
+                _pingTimer?.Stop();
+            }
+            catch (Exception e)
+            {
+                _logger.Error("Error during ping timer stop", e);
+            }
+        }
+
         private void RunPeerCommit()
         {
             if (!_peerStorage.AnyPendingChange())
@@ -672,5 +714,53 @@ namespace Nethermind.Network
             _peerStorage.Commit();
             _peerStorage.StartBatch();
         }
+
+        private async Task SendPingMessages()
+        {
+            var pingTasks = new List<(Peer peer, Task<bool> pingTask)>();
+            foreach (var activePeer in ActivePeers)
+            {
+                if (activePeer.P2PMessageSender != null)
+                {
+                    var pingTask = SendPingMessage(activePeer);
+                    pingTasks.Add((activePeer, pingTask));
+                }
+            }
+
+            if (pingTasks.Any())
+            {
+                var tasks = await Task.WhenAll(pingTasks.Select(x => x.pingTask));
+
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Sent ping messages to {tasks.Length} peers. Disconnected: {tasks.Count(x => x == false)}");
+                }
+                return;
+            }
+
+            if (_logger.IsDebugEnabled)
+            {
+                _logger.Debug("Sent no ping messages.");
+            }
+        }
+
+        private async Task<bool> SendPingMessage(Peer peer)
+        {
+            for (var i = 0; i < _configurationProvider.P2PPingRetryCount; i++)
+            {
+                var result = await peer.P2PMessageSender.SendPing();
+                if (result)
+                {
+                    return true;
+                }
+            }
+            if (_logger.IsInfoEnabled)
+            {
+                _logger.Info($"Disconnecting due to missed ping messages: {peer.Session.RemoteNodeId}");
+            }
+            await peer.Session.InitiateDisconnectAsync(DisconnectReason.ReceiveMessageTimeout);
+
+            return false;
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 99a33c95c..635e73fd1 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -149,7 +149,10 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error($"{GetType().Name} exception", exception);
+            if (_logger.IsDebugEnabled)
+            {
+                _logger.Debug($"{GetType().Name} exception: {exception}");
+            }
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 65f1c8d85..78f6d858a 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -114,9 +114,9 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled)
+            if (_logger.IsDebugEnabled)
             {
-                _logger.Error($"{GetType().Name} exception", exception);
+                _logger.Debug($"{GetType().Name} exception: {exception}");
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 7df59f123..face8d07e 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -23,5 +23,6 @@ namespace Nethermind.Network
     public class Timeouts
     {
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
+        public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
     }
 }
\ No newline at end of file
