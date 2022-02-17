commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
commit cec4b6b43901149d21003211f8132e9ebeb75070
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Fri Oct 29 16:12:35 2021 +0200

    Reduce memory usage when requesting transactions (#3551)
    
    * Rewrite PooledTxsRequestor not to allocate List and Array on each call
    
    Move hashes message to IReadOnlyList<>
    Make ArrayPoolList<> implement IReadOnlyList<>
    Make LruKeyCache<>.Set return bool and use it to reduce operations
    
    * Dispose ArrayPoolLists
    
    * fix test, copy collection within test as later it will be disposed (in normal code its being serialized then)

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
index d0995a8c5..58dc9b389 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/ISyncPeer.cs
@@ -41,11 +41,11 @@ namespace Nethermind.Blockchain.Synchronization
         UInt256 TotalDifficulty { get; set; }
         bool IsInitialized { get; set; }
         void Disconnect(DisconnectReason reason, string details);
-        Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token);
+        Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token);
         Task<BlockHeader[]> GetBlockHeaders(long number, int maxBlocks, int skip, CancellationToken token);
         Task<BlockHeader?> GetHeadBlockHeader(Keccak hash, CancellationToken token);
         void NotifyOfNewBlock(Block block, SendBlockPriority priority);
-        Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token);
-        Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token);
+        Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token);
+        Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token);
     }
 }
diff --git a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
index b269f9ab6..078f16c64 100644
--- a/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
+++ b/src/Nethermind/Nethermind.Core.Test/Caching/LruKeyCacheTests.cs
@@ -56,8 +56,8 @@ namespace Nethermind.Core.Test.Caching
         public void Can_reset()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
+            cache.Set(_addresses[0]).Should().BeFalse();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
@@ -72,10 +72,10 @@ namespace Nethermind.Core.Test.Caching
         public void Can_clear()
         {
             LruKeyCache<Address> cache = new(Capacity, "test");
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Clear();
             cache.Get(_addresses[0]).Should().BeFalse();
-            cache.Set(_addresses[0]);
+            cache.Set(_addresses[0]).Should().BeTrue();
             cache.Get(_addresses[0]).Should().BeTrue();
         }
         
diff --git a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
index db34de464..90c4024e4 100644
--- a/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
+++ b/src/Nethermind/Nethermind.Core/Caching/LruKeyCache.cs
@@ -87,6 +87,7 @@ namespace Nethermind.Core.Caching
                     _lruList.AddLast(newNode);
                     _cacheMap.Add(key, newNode);    
                 }
+                
                 return true;
             }
         }
diff --git a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
index 74aa9d736..627204b1b 100644
--- a/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
+++ b/src/Nethermind/Nethermind.Core/Collections/ArrayPoolList.cs
@@ -22,10 +22,11 @@ using System.Collections.Generic;
 using System.Runtime.CompilerServices;
 using System.Threading;
 using System.Threading.Tasks;
+using Nethermind.Core.Crypto;
 
 namespace Nethermind.Core.Collections
 {
-    public class ArrayPoolList<T> : IList<T>, IDisposable
+    public class ArrayPoolList<T> : IList<T>, IReadOnlyList<T>, IDisposable
     {
         private readonly ArrayPool<T> _arrayPool;
         private T[] _array;
@@ -38,6 +39,11 @@ namespace Nethermind.Core.Collections
             
         }
         
+        public ArrayPoolList(int capacity, IEnumerable<T> enumerable) : this(capacity)
+        {
+            this.AddRange(enumerable);
+        }
+        
         public ArrayPoolList(ArrayPool<T> arrayPool, int capacity)
         {
             _arrayPool = arrayPool;
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
index 4327e4a9d..08f5666eb 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V65/PooledTxsRequestorTests.cs
@@ -17,6 +17,7 @@
 
 using System;
 using System.Collections.Generic;
+using System.Linq;
 using FluentAssertions;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
@@ -34,7 +35,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         private IPooledTxsRequestor _requestor;
         private IReadOnlyList<Keccak> _request;
         private IList<Keccak> _expected;
-        private IList<Keccak> _response;
+        private IReadOnlyList<Keccak> _response;
         
         
         [Test]
@@ -99,7 +100,7 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V65
         
         private void Send(GetPooledTransactionsMessage msg)
         {
-            _response = msg.Hashes;
+            _response = msg.Hashes.ToList();
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
index 1839bdf8b..ccbdad15d 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/HashesMessage.cs
@@ -22,12 +22,12 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 {
     public abstract class HashesMessage : P2PMessage
     {
-        protected HashesMessage(IList<Keccak> hashes)
+        protected HashesMessage(IReadOnlyList<Keccak> hashes)
         {
             Hashes = hashes ?? throw new ArgumentNullException(nameof(hashes));
         }
         
-        public IList<Keccak> Hashes { get; }
+        public IReadOnlyList<Keccak> Hashes { get; }
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
index 7ddffbb28..452a0db4f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V62/GetBlockBodiesMessage.cs
@@ -21,16 +21,16 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V62
 {
     public class GetBlockBodiesMessage : P2PMessage
     {
-        public IList<Keccak> BlockHashes { get; }
+        public IReadOnlyList<Keccak> BlockHashes { get; }
         public override int PacketType { get; } = Eth62MessageCode.GetBlockBodies;
         public override string Protocol { get; } = "eth";
         
-        public GetBlockBodiesMessage(IList<Keccak> blockHashes)
+        public GetBlockBodiesMessage(IReadOnlyList<Keccak> blockHashes)
         {
             BlockHashes = blockHashes;
         }
 
-        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IList<Keccak>)blockHashes)
+        public GetBlockBodiesMessage (params Keccak[] blockHashes) : this((IReadOnlyList<Keccak>)blockHashes)
         {
         }
 
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 2fe781a3d..f24ac641f 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -118,7 +118,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             _nodeDataRequests.Handle(msg.Data, size);
         }
 
-        public override async Task<byte[][]> GetNodeData(IList<Keccak> keys, CancellationToken token)
+        public override async Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> keys, CancellationToken token)
         {
             if (keys.Count == 0)
             {
@@ -132,7 +132,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             byte[][] nodeData = await SendRequest(msg, token);
             return nodeData;
         }
-        public override async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHashes, CancellationToken token)
+        public override async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
index da80154e3..9fbe24612 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetNodeDataMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetNodeData;
         public override string Protocol { get; } = "eth";
 
-        public GetNodeDataMessage(IList<Keccak> keys)
+        public GetNodeDataMessage(IReadOnlyList<Keccak> keys)
             : base(keys)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
index 16cdefb85..218709830 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/GetReceiptsMessage.cs
@@ -24,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
         public override int PacketType { get; } = Eth63MessageCode.GetReceipts;
         public override string Protocol { get; } = "eth";
 
-        public GetReceiptsMessage(IList<Keccak> blockHashes)
+        public GetReceiptsMessage(IReadOnlyList<Keccak> blockHashes)
             : base(blockHashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
index 1380405ce..162f445c4 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/Eth65ProtocolHandler.cs
@@ -148,7 +148,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
             }
         }
         
-        private void SendMessage(IList<Keccak> hashes)
+        private void SendMessage(IReadOnlyList<Keccak> hashes)
         {
             NewPooledTransactionHashesMessage msg = new(hashes);
             Send(msg);
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
index 3f8d04ea4..8617c9a84 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/GetPooledTransactionsMessage.cs
@@ -14,6 +14,7 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using System.Collections.Generic;
 using Nethermind.Core.Crypto;
 
 namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
@@ -23,7 +24,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.GetPooledTransactions;
         public override string Protocol { get; } = "eth";
 
-        public GetPooledTransactionsMessage(Keccak[] hashes)
+        public GetPooledTransactionsMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
index 34f3c4ca6..9db696695 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/NewPooledTransactionHashesMessage.cs
@@ -26,7 +26,7 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         public override int PacketType { get; } = Eth65MessageCode.NewPooledTransactionHashes;
         public override string Protocol { get; } = "eth";
 
-        public NewPooledTransactionHashesMessage(IList<Keccak> hashes)
+        public NewPooledTransactionHashesMessage(IReadOnlyList<Keccak> hashes)
             : base(hashes)
         {
         }
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
index 1632a4ae6..6be3c2356 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V65/PooledTxsRequestor.cs
@@ -19,6 +19,7 @@ using System;
 using System.Collections.Generic;
 using System.Linq;
 using Nethermind.Core.Caching;
+using Nethermind.Core.Collections;
 using Nethermind.Core.Crypto;
 using Nethermind.TxPool;
 
@@ -37,45 +38,37 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V65
         
         public void RequestTransactions(Action<GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes));
             
             if (discoveredTxHashes.Count != 0)
             {
-                send(new GetPooledTransactionsMessage(discoveredTxHashes.ToArray()));
+                send(new GetPooledTransactionsMessage(discoveredTxHashes));
                 Metrics.Eth65GetPooledTransactionsRequested++;
             }
         }
 
         public void RequestTransactionsEth66(Action<Eth.V66.GetPooledTransactionsMessage> send, IReadOnlyList<Keccak> hashes)
         {
-            IList<Keccak> discoveredTxHashes = GetAndMarkUnknownHashes(hashes);
-            
+            using ArrayPoolList<Keccak> discoveredTxHashes = new(hashes.Count, GetAndMarkUnknownHashes(hashes)); 
+
             if (discoveredTxHashes.Count != 0)
             {
-                GetPooledTransactionsMessage msg65 = new GetPooledTransactionsMessage(discoveredTxHashes.ToArray());
+                GetPooledTransactionsMessage msg65 = new(discoveredTxHashes);
                 send(new V66.GetPooledTransactionsMessage() {EthMessage = msg65});
                 Metrics.Eth66GetPooledTransactionsRequested++;
             }
         }
         
-        private IList<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
+        private IEnumerable<Keccak> GetAndMarkUnknownHashes(IReadOnlyList<Keccak> hashes)
         {
-            List<Keccak> discoveredTxHashes = new();
-            
             for (int i = 0; i < hashes.Count; i++)
             {
                 Keccak hash = hashes[i];
-                if (!_txPool.IsKnown(hash))
+                if (!_txPool.IsKnown(hash) && _pendingHashes.Set(hash))
                 {
-                    if (!_pendingHashes.Get(hash))
-                    {
-                        discoveredTxHashes.Add(hash);
-                        _pendingHashes.Set(hash);
-                    }
+                    yield return hash;
                 }
             }
-
-            return discoveredTxHashes;
         }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
index 600bdd87d..62b626d71 100644
--- a/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/SyncPeerProtocolHandlerBase.cs
@@ -83,7 +83,7 @@ namespace Nethermind.Network.P2P
             Session.InitiateDisconnect(reason, details);
         }
 
-        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        async Task<BlockBody[]> ISyncPeer.GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             if (blockHashes.Count == 0)
             {
@@ -205,12 +205,12 @@ namespace Nethermind.Network.P2P
             return headers.Length > 0 ? headers[0] : null;
         }
 
-        public virtual Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public virtual Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
 
-        public virtual Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public virtual Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotSupportedException("Fast sync not supported by eth62 protocol");
         }
@@ -343,7 +343,7 @@ namespace Nethermind.Network.P2P
 
         protected BlockBodiesMessage FulfillBlockBodiesRequest(GetBlockBodiesMessage getBlockBodiesMessage)
         {
-            IList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
+            IReadOnlyList<Keccak> hashes = getBlockBodiesMessage.BlockHashes;
             Block[] blocks = new Block[hashes.Count];
 
             ulong sizeEstimate = 0;
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
index 2f2bcf3fd..b5760d5db 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/BlockDownloaderTests.cs
@@ -226,7 +226,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(async ci => await ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.TimeoutOnFullBatch));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -255,7 +255,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.AllKnown));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.AllKnown));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -280,7 +280,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -304,7 +304,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect | Response.NoBody));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.JustFirst));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -441,7 +441,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -471,7 +471,7 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect));
 
             syncPeer.TotalDifficulty.Returns(UInt256.MaxValue);
@@ -538,7 +538,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -570,12 +570,12 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -617,10 +617,10 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<BlockBody[]>(new TimeoutException()));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -651,10 +651,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(Task.FromException<TxReceipt[][]>(new TimeoutException()));
 
             PeerInfo peerInfo = new(syncPeer);
@@ -702,13 +702,13 @@ namespace Nethermind.Synchronization.Test
             syncPeer.GetBlockHeaders(Arg.Any<long>(), Arg.Any<int>(), Arg.Any<int>(), Arg.Any<CancellationToken>())
                 .Returns(ci => syncPeerInternal.GetBlockHeaders(ci.ArgAt<long>(0), ci.ArgAt<int>(1), ci.ArgAt<int>(2), ci.ArgAt<CancellationToken>(3)));
 
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
-                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
+                .Returns(ci => syncPeerInternal.GetBlockBodies(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1)));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(async ci =>
                 {
-                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
+                    TxReceipt[][] receipts = await syncPeerInternal.GetReceipts(ci.ArgAt<IReadOnlyList<Keccak>>(0), ci.ArgAt<CancellationToken>(1));
                     receipts[^1] = null;
                     return receipts;
                 });
@@ -752,10 +752,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result.Skip(1).ToArray());
 
             PeerInfo peerInfo = new(syncPeer);
@@ -783,10 +783,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.AllCorrect));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions)
                     .Result.Select(r => r == null || r.Length == 0 ? r : r.Skip(1).ToArray()).ToArray());
 
@@ -816,10 +816,10 @@ namespace Nethermind.Synchronization.Test
                 .Returns(ci => buildHeadersResponse = ctx.ResponseBuilder.BuildHeaderResponse(ci.ArgAt<long>(0), ci.ArgAt<int>(1), Response.IncorrectReceiptRoot));
 
             Task<BlockBody[]> buildBlocksResponse = null;
-            syncPeer.GetBlockBodies(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetBlockBodies(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => buildBlocksResponse = ctx.ResponseBuilder.BuildBlocksResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions));
 
-            syncPeer.GetReceipts(Arg.Any<IList<Keccak>>(), Arg.Any<CancellationToken>())
+            syncPeer.GetReceipts(Arg.Any<IReadOnlyList<Keccak>>(), Arg.Any<CancellationToken>())
                 .Returns(ci => ctx.ResponseBuilder.BuildReceiptsResponse(ci.ArgAt<IList<Keccak>>(0), Response.AllCorrect | Response.WithTransactions).Result);
 
             PeerInfo peerInfo = new(syncPeer);
@@ -938,7 +938,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public async Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 bool consistent = Flags.HasFlag(Response.Consistent);
                 bool justFirst = Flags.HasFlag(Response.JustFirst);
@@ -1003,7 +1003,7 @@ namespace Nethermind.Synchronization.Test
                 throw new NotImplementedException();
             }
 
-            public async Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public async Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 TxReceipt[][] receipts = new TxReceipt[blockHash.Count][];
                 int i = 0;
@@ -1019,7 +1019,7 @@ namespace Nethermind.Synchronization.Test
                 return await Task.FromResult(_receiptsSerializer.Deserialize(messageSerialized).TxReceipts);
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index 3ec22e507..4eac2ed4d 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -185,11 +185,11 @@ namespace Nethermind.Synchronization.Test.FastSync
             private readonly IDb _codeDb;
             private readonly IDb _stateDb;
 
-            private Func<IList<Keccak>, Task<byte[][]>> _executorResultFunction;
+            private Func<IReadOnlyList<Keccak>, Task<byte[][]>> _executorResultFunction;
 
             private Keccak[] _filter;
 
-            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IList<Keccak>, Task<byte[][]>> executorResultFunction = null)
+            public SyncPeerMock(IDb stateDb, IDb codeDb, Func<IReadOnlyList<Keccak>, Task<byte[][]>> executorResultFunction = null)
             {
                 _stateDb = stateDb;
                 _codeDb = codeDb;
@@ -213,7 +213,7 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
@@ -245,12 +245,12 @@ namespace Nethermind.Synchronization.Test.FastSync
                 throw new NotImplementedException();
             }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 if (_executorResultFunction != null) return _executorResultFunction(hashes);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
index ade13531d..5896b7f93 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/LatencySyncPeerMock.cs
@@ -72,7 +72,7 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
@@ -104,12 +104,12 @@ namespace Nethermind.Synchronization.Test
             throw new NotImplementedException();
         }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             throw new NotImplementedException();
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             throw new NotImplementedException();
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
index adbe2210e..02d69d42f 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerMock.cs
@@ -85,7 +85,7 @@ namespace Nethermind.Synchronization.Test
         {
         }
 
-        public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+        public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
         {
             BlockBody[] result = new BlockBody[blockHashes.Count];
             for (int i = 0; i < blockHashes.Count; i++)
@@ -168,7 +168,7 @@ namespace Nethermind.Synchronization.Test
         
         public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-        public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+        public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
         {
             TxReceipt[][] result = new TxReceipt[blockHash.Count][];
             for (int i = 0; i < blockHash.Count; i++)
@@ -179,7 +179,7 @@ namespace Nethermind.Synchronization.Test
             return Task.FromResult(result);
         }
 
-        public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+        public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
         {
             return Task.FromResult(_remoteSyncServer.GetNodeData(hashes));
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
index 101d7f478..f0ebbf875 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncPeerPoolTests.cs
@@ -80,7 +80,7 @@ namespace Nethermind.Synchronization.Test
                 DisconnectRequested = true;
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<BlockBody>());
             }
@@ -119,12 +119,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<TxReceipt[]>());
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 return Task.FromResult(Array.Empty<byte[]>());
             }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index f9ba22a2c..6c0293906 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -105,7 +105,7 @@ namespace Nethermind.Synchronization.Test
                 Disconnected?.Invoke(this, EventArgs.Empty);
             }
 
-            public Task<BlockBody[]> GetBlockBodies(IList<Keccak> blockHashes, CancellationToken token)
+            public Task<BlockBody[]> GetBlockBodies(IReadOnlyList<Keccak> blockHashes, CancellationToken token)
             {
                 if (_causeTimeoutOnBlocks)
                 {
@@ -195,12 +195,12 @@ namespace Nethermind.Synchronization.Test
             
             public void SendNewTransactions(IEnumerable<Transaction> txs) { }
 
-            public Task<TxReceipt[][]> GetReceipts(IList<Keccak> blockHash, CancellationToken token)
+            public Task<TxReceipt[][]> GetReceipts(IReadOnlyList<Keccak> blockHash, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
 
-            public Task<byte[][]> GetNodeData(IList<Keccak> hashes, CancellationToken token)
+            public Task<byte[][]> GetNodeData(IReadOnlyList<Keccak> hashes, CancellationToken token)
             {
                 throw new NotImplementedException();
             }
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
index 8491de2d5..471dab7d3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloadContext.cs
@@ -81,7 +81,7 @@ namespace Nethermind.Synchronization.Blocks
 
         public List<Keccak> NonEmptyBlockHashes { get; }
 
-        public IList<Keccak> GetHashesByOffset(int offset, int maxLength)
+        public IReadOnlyList<Keccak> GetHashesByOffset(int offset, int maxLength)
         {
             var hashesToRequest =
                 offset == 0
diff --git a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
index 673320055..dd36bd1c3 100644
--- a/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
+++ b/src/Nethermind/Nethermind.Synchronization/Blocks/BlockDownloader.cs
@@ -425,7 +425,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxBodiesPerRequest());
                 Task<BlockBody[]> getBodiesRequest = peer.SyncPeer.GetBlockBodies(hashesToRequest, cancellation);
                 await getBodiesRequest.ContinueWith(_ => DownloadFailHandler(getBodiesRequest, "bodies"), cancellation);
                 BlockBody[] result = getBodiesRequest.Result;
@@ -443,7 +443,7 @@ namespace Nethermind.Synchronization.Blocks
             int offset = 0;
             while (offset != context.NonEmptyBlockHashes.Count)
             {
-                IList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
+                IReadOnlyList<Keccak> hashesToRequest = context.GetHashesByOffset(offset, peer.MaxReceiptsPerRequest());
                 Task<TxReceipt[][]> request = peer.SyncPeer.GetReceipts(hashesToRequest, cancellation);
                 await request.ContinueWith(_ => DownloadFailHandler(request, "receipts"), cancellation);
 
diff --git a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
index f7d3c7e95..efc73828f 100644
--- a/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/ISyncServer.cs
@@ -36,7 +36,7 @@ namespace Nethermind.Synchronization
         public CanonicalHashTrie? GetCHT();
         Keccak? FindHash(long number);
         BlockHeader[] FindHeaders(Keccak hash, int numberOfBlocks, int skip, bool reverse);
-        byte[]?[] GetNodeData(IList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
+        byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys, NodeDataType includedTypes = NodeDataType.Code | NodeDataType.State);
         int GetPeerCount();
         ulong ChainId { get; }
         BlockHeader Genesis { get; }
diff --git a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
index c0aebcfca..7f9ecf1b2 100644
--- a/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
+++ b/src/Nethermind/Nethermind.Synchronization/SyncServer.cs
@@ -342,7 +342,7 @@ namespace Nethermind.Synchronization
             return _blockTree.FindHeaders(hash, numberOfBlocks, skip, reverse);
         }
 
-        public byte[]?[] GetNodeData(IList<Keccak> keys,
+        public byte[]?[] GetNodeData(IReadOnlyList<Keccak> keys,
             NodeDataType includedTypes = NodeDataType.State | NodeDataType.Code)
         {
             byte[]?[] values = new byte[keys.Count][];
diff --git a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
index 5fbe3b9ba..177be50d6 100644
--- a/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
+++ b/src/Nethermind/Nethermind.TxPool/PeerInfo.cs
@@ -52,9 +52,8 @@ namespace Nethermind.TxPool
         {
             foreach (Transaction tx in txs)
             {
-                if (!NotifiedTransactions.Get(tx.Hash))
+                if (NotifiedTransactions.Set(tx.Hash))
                 {
-                    NotifiedTransactions.Set(tx.Hash);
                     yield return tx;
                 }
             }
