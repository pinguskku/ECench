commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
commit 782ad85d40635d8e76360a0d45f23a73886cc793
Author: Grzegorz Lesniakiewicz <glesniakiewicz@gmail.com>
Date:   Sat Jul 7 22:51:48 2018 -0400

    Fixing sending too many messages to peers, improved logging, handled few network edge cases

diff --git a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
index c44fc3341..1aac8123a 100644
--- a/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
+++ b/src/Nethermind/Nethermind.Blockchain/SynchronizationManager.cs
@@ -311,6 +311,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewPendingTransaction(object sender, TransactionEventArgs transactionEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Transaction transaction = transactionEventArgs.Transaction;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
@@ -361,6 +366,11 @@ namespace Nethermind.Blockchain
 
         private void OnNewHeadBlock(object sender, BlockEventArgs blockEventArgs)
         {
+            if (_isSyncing)
+            {
+                return;
+            }
+
             Block block = blockEventArgs.Block;
             foreach ((NodeId nodeId, PeerInfo peerInfo) in _peers)
             {
diff --git a/src/Nethermind/Nethermind.Core/ChainId.cs b/src/Nethermind/Nethermind.Core/ChainId.cs
index 6175b56bd..98253b3c7 100644
--- a/src/Nethermind/Nethermind.Core/ChainId.cs
+++ b/src/Nethermind/Nethermind.Core/ChainId.cs
@@ -31,5 +31,36 @@ namespace Nethermind.Core
         public const int EthereumClassicMainnet = 61;
         public const int EthereumClassicTestnet = 62;
         public const int DefaultGethPrivateChain = 1337;
+
+        public static string GetChainName(int chaninId)
+        {
+            switch (chaninId)
+            {
+                case Olympic:
+                    return "Olympic";
+                case MainNet:
+                    return "MainNet";
+                case Morden:
+                    return "Morden";
+                case Ropsten:
+                    return "Ropsten";
+                case Rinkeby:
+                    return "Rinkeby";
+                case RootstockMainnet:
+                    return "RootstockMainnet";
+                case RootstockTestnet:
+                    return "RootstockTestnet";
+                case Kovan:
+                    return "Kovan";
+                case EthereumClassicMainnet:
+                    return "EthereumClassicMainnet";
+                case EthereumClassicTestnet:
+                    return "EthereumClassicTestnet";
+                case DefaultGethPrivateChain:
+                    return "DefaultGethPrivateChain";
+            }
+
+            return chaninId.ToString();
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
index e45fbf1b4..dd22060af 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/NettyDiscoveryHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Transport.Channels;
 using DotNetty.Transport.Channels.Sockets;
@@ -49,7 +50,22 @@ namespace Nethermind.Network.Discovery
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            _logger.Error("Exception when processing discovery messages", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"Exception when processing discovery messages (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing discovery messages", exception);
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
index f0e610cf4..d22679f47 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Multiplexor.cs
@@ -66,11 +66,27 @@ namespace Nethermind.Network.P2P
             {
                 if (t.IsFaulted)
                 {
-                    _logger.Error($"{nameof(NettyP2PHandler)} exception", t.Exception);
+                    if (_context.Channel != null && !_context.Channel.Active)
+                    {
+                        if (_logger.IsDebugEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is not active", t.Exception);
+                        }
+                    }
+                    else
+                    {
+                        if (_logger.IsErrorEnabled)
+                        {
+                            _logger.Error($"{nameof(NettyP2PHandler)} error in multiplexor, channel is active", t.Exception);
+                        }
+                    }
                 }
                 else if (t.IsCompleted)
                 {
-                    _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    if (_logger.IsDebugEnabled)
+                    {
+                        _logger.Debug($"Packet ({packet.Protocol}.{packet.PacketType}) pushed");
+                    }
                 }
             });
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
index 373ed1e31..d2d72a4fa 100644
--- a/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/NettyP2PHandler.cs
@@ -17,6 +17,7 @@
  */
 
 using System;
+using System.Net.Sockets;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
 using Nethermind.Core.Logging;
@@ -62,10 +63,21 @@ namespace Nethermind.Network.P2P
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in p2p netty handler: {exception}");
+                }
+            } 
 
             base.ExceptionCaught(context, exception);
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
index ea7840b1d..d35c58513 100644
--- a/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/P2PSession.cs
@@ -132,6 +132,15 @@ namespace Nethermind.Network.P2P
 
         public async Task InitiateDisconnectAsync(DisconnectReason disconnectReason)
         {
+            if (_wasDisconnected)
+            {
+                if (_logger.IsInfoEnabled)
+                {
+                    _logger.Info($"Session was already disconnected: {RemoteNodeId}, sessioId: {SessionId}");
+                }
+                return;
+            }
+
             //Trigger disconnect on each protocol handler (if p2p is initialized it will send disconnect message to the peer)
             if (_protocols.Any())
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index 283d7cde8..ff81464ec 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -218,14 +218,42 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             if (status.ChainId != _sync.BlockTree.ChainId)
             {
-                throw new InvalidOperationException("network ID mismatch");
-                // TODO: disconnect here
+                if (Logger.IsInfoEnabled)
+                {
+                    Logger.Info($"Network id mismatch, initiating disconnect, Node: {P2PSession.RemoteNodeId}, our network: {ChainId.GetChainName(_sync.BlockTree.ChainId)}, theirs: {ChainId.GetChainName((int)status.ChainId)}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.Other).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
             
             if (status.GenesisHash != _sync.Genesis.Hash)
             {
-                Logger.Warn($"{P2PSession.RemoteNodeId} Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash}");
-                throw new InvalidOperationException("genesis hash mismatch");
+                if (Logger.IsWarnEnabled)
+                {
+                    Logger.Warn($"Connected peer's genesis hash {status.GenesisHash} differes from {_sync.Genesis.Hash} initiating disconnect, Node: {P2PSession.RemoteNodeId}");
+                }
+
+                P2PSession.InitiateDisconnectAsync(DisconnectReason.BreachOfProtocol).ContinueWith(x =>
+                {
+                    if (x.IsFaulted)
+                    {
+                        if (Logger.IsErrorEnabled)
+                        {
+                            Logger.Error($"Error while disconnecting: {P2PSession.RemoteNodeId}", x.Exception);
+                        }
+                    }
+                });
+                return;
             }
 
             //if (!_statusSent)
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 1e7ef9d31..ba825531c 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -392,7 +392,7 @@ namespace Nethermind.Network
                             ? DateTime.Now.Subtract(candidateNode.NodeStats.LastDisconnectTime.Value).TotalMilliseconds.ToString()
                             : "no disconnect";
 
-                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}");
+                        _logger.Warn($"Protocol initialized for peer not present in active collection, id: {session.RemoteNodeId}, time from last disconnect: {timeFromLastDisconnect}.");
                     }
                 }
                 else
@@ -403,6 +403,9 @@ namespace Nethermind.Network
                     }
                 }
 
+                //Initializing disconnect if it hasnt been done already - in case of e.g. timeout earier and unexcepted further connection
+                await session.InitiateDisconnectAsync(DisconnectReason.Other);
+
                 return;
             }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
index 22383c65b..cda0128bb 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameDecoder.cs
@@ -19,6 +19,7 @@
 using System;
 using System.Collections.Generic;
 using System.Linq;
+using System.Net.Sockets;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
@@ -150,10 +151,22 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decder (SocketException): {exception}");
+                }
             }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame decoder: {exception}");
+                }
+            }
+
             base.ExceptionCaught(context, exception);
         }
         
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
index 7b458f455..b9e9bebec 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyFrameMerger.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Net.Sockets;
 using DotNetty.Codecs;
 using DotNetty.Transport.Channels;
 using Nethermind.Core;
@@ -116,9 +117,20 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsDebugEnabled)
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
             {
-                _logger.Debug($"{GetType().Name} exception: {exception}");
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger (SocketException): {exception}");
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error($"{GetType().Name} error in netty frame merger: {exception}");
+                }
             }
 
             base.ExceptionCaught(context, exception);
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
index a3df27548..d100816af 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/NettyHandshakeHandler.cs
@@ -18,6 +18,7 @@
 
 using System;
 using System.Net;
+using System.Net.Sockets;
 using System.Threading.Tasks;
 using DotNetty.Buffers;
 using DotNetty.Codecs;
@@ -110,7 +111,21 @@ namespace Nethermind.Network.Rlpx
 
         public override void ExceptionCaught(IChannelHandlerContext context, Exception exception)
         {
-            if (_logger.IsErrorEnabled) _logger.Error("Exception when processing encryption handshake", exception);
+            //In case of SocketException we log it as debug to avoid noise
+            if (exception is SocketException)
+            {
+                if (_logger.IsDebugEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake (SocketException):", exception);
+                }
+            }
+            else
+            {
+                if (_logger.IsErrorEnabled)
+                {
+                    _logger.Error("Exception when processing encryption handshake", exception);
+                }
+            }
             base.ExceptionCaught(context, exception);
         }
 
diff --git a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
index 687aba995..07761e933 100644
--- a/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
+++ b/src/Nethermind/Nethermind.Network/Rlpx/RlpxPeer.cs
@@ -41,7 +41,6 @@ namespace Nethermind.Network.Rlpx
     // TODO: integration tests for this one
     public class RlpxPeer : IRlpxPeer
     {
-        private const int PeerConnectionTimeout = 10000;
         private readonly int _localPort;
         private readonly IEncryptionHandshakeService _encryptionHandshakeService;
         private readonly IMessageSerializationService _serializationService;
@@ -153,13 +152,13 @@ namespace Nethermind.Network.Rlpx
 
             clientBootstrap.Option(ChannelOption.TcpNodelay, true);
             clientBootstrap.Option(ChannelOption.MessageSizeEstimator, DefaultMessageSizeEstimator.Default);
-            clientBootstrap.Option(ChannelOption.ConnectTimeout, TimeSpan.FromMilliseconds(PeerConnectionTimeout));
+            clientBootstrap.Option(ChannelOption.ConnectTimeout, Timeouts.InitialConnection);
             clientBootstrap.RemoteAddress(host, port);
 
             clientBootstrap.Handler(new ActionChannelInitializer<ISocketChannel>(ch => InitializeChannel(ch, EncryptionHandshakeRole.Initiator, remoteId, host, port)));
 
             var connectTask = clientBootstrap.ConnectAsync(new IPEndPoint(IPAddress.Parse(host), port));
-            var firstTask = await Task.WhenAny(connectTask, Task.Delay(5000));
+            var firstTask = await Task.WhenAny(connectTask, Task.Delay(Timeouts.InitialConnection));
             if (firstTask != connectTask)
             {
                 _logger.Debug($"Connection timed out: {remoteId}@{host}:{port}");
diff --git a/src/Nethermind/Nethermind.Network/Timeouts.cs b/src/Nethermind/Nethermind.Network/Timeouts.cs
index 6633e67dc..d69a368a0 100644
--- a/src/Nethermind/Nethermind.Network/Timeouts.cs
+++ b/src/Nethermind/Nethermind.Network/Timeouts.cs
@@ -22,6 +22,7 @@ namespace Nethermind.Network
 {
     public class Timeouts
     {
+        public static readonly TimeSpan InitialConnection = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan Eth62 = TimeSpan.FromSeconds(10);
         public static readonly TimeSpan P2PPing = TimeSpan.FromSeconds(5);
         public static readonly TimeSpan P2PHello = TimeSpan.FromSeconds(5);
diff --git a/src/Nethermind/Nethermind.Runner/NLog.config b/src/Nethermind/Nethermind.Runner/NLog.config
index ea9ead93e..3c91d201e 100644
--- a/src/Nethermind/Nethermind.Runner/NLog.config
+++ b/src/Nethermind/Nethermind.Runner/NLog.config
@@ -40,11 +40,12 @@
   </targets>
 
   <rules>
-    <logger name="*" maxlevel="Trace" final="true" />
-    <logger name="Network.*" maxlevel="Info" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="colored-console-async" final="true"/>
-    <logger name="Network.*" minlevel="Warn" writeTo="file-async" final="true"/>
-    <logger name="*" minlevel="Debug" writeTo="file-async"/>
+    <logger name="*" maxlevel="Debug" final="true" />
+    <logger name="Network.*" maxlevel="Debug" final="true"/>
+    <!--<logger name="Network.*" minlevel="Info"  final="true"/>-->
+    <!--<logger name="Network.*" minlevel="Info" writeTo="colored-console-async" final="true"/>-->
+    <logger name="Network.*" minlevel="Info" writeTo="file-async" final="true"/>
+    <logger name="*" minlevel="Info" writeTo="file-async"/>
     <logger name="*" minlevel="Info" writeTo="colored-console-async"/>
   </rules>
 </nlog>
\ No newline at end of file
