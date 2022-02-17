commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
commit 65db33fa3f13c731b1ce218c2752b803adaa0269
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Tue Dec 17 15:46:16 2019 +0000

    the leak - sync peers (#1155)
    
    * the leak - sync peers
    
    * Disposal of linked CancellationTokenSources
    
    * Missed disposal of CTS on return addressed

diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
index 676a2e55b..39e429726 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/EthSyncPeerPool.cs
@@ -339,56 +339,64 @@ namespace Nethermind.Blockchain.Synchronization
             await firstToComplete.ContinueWith(
                 t =>
                 {
-                    if (firstToComplete.IsFaulted || firstToComplete == delayTask)
+                    try
                     {
-                        if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
-                        syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                    }
-                    else if (firstToComplete.IsCanceled)
-                    {
-                        if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                        _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
-                        token.ThrowIfCancellationRequested();
-                    }
-                    else
-                    {
-                        delaySource.Cancel();
-                        BlockHeader header = getHeadHeaderTask.Result; 
-                        if (header == null)
+                        if (firstToComplete.IsFaulted || firstToComplete == delayTask)
                         {
                             if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
-                            
-                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed: NodeStatsEventType.SyncInitFailed);
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
                             syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
-                            return;
                         }
-
-                        if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
-                        if (!peerInfo.IsInitialized)
+                        else if (firstToComplete.IsCanceled)
                         {
-                            _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            if (_logger.IsTrace) _logger.Trace($"InitPeerInfo canceled for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
+                            _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncCancelled : NodeStatsEventType.SyncInitCancelled);
+                            token.ThrowIfCancellationRequested();
                         }
+                        else
+                        {
+                            delaySource.Cancel();
+                            BlockHeader header = getHeadHeaderTask.Result;
+                            if (header == null)
+                            {
+                                if (_logger.IsDebug) _logger.Debug($"InitPeerInfo failed for node: {syncPeer.Node:c}{Environment.NewLine}{t.Exception}");
 
-                        if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
-                        peerInfo.HeadNumber = header.Number;
-                        peerInfo.HeadHash = header.Hash;
+                                _stats.ReportSyncEvent(syncPeer.Node, peerInfo.IsInitialized ? NodeStatsEventType.SyncFailed : NodeStatsEventType.SyncInitFailed);
+                                syncPeer.Disconnect(DisconnectReason.DisconnectRequested, "refresh peer info fault");
+                                return;
+                            }
 
-                        BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
-                        if (parent != null)
-                        {
-                            peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
-                        }
+                            if (_logger.IsTrace) _logger.Trace($"Received head block info from {syncPeer.Node:c} with head block numer {header.Number}");
+                            if (!peerInfo.IsInitialized)
+                            {
+                                _stats.ReportSyncEvent(syncPeer.Node, NodeStatsEventType.SyncInitCompleted);
+                            }
 
-                        peerInfo.IsInitialized = true;
-                        foreach ((SyncPeerAllocation allocation, object _) in _allocations)
-                        {
-                            if (allocation.Current == peerInfo)
+                            if (_logger.IsTrace) _logger.Trace($"REFRESH Updating header of {peerInfo} from {peerInfo.HeadNumber} to {header.Number}");
+                            peerInfo.HeadNumber = header.Number;
+                            peerInfo.HeadHash = header.Hash;
+
+                            BlockHeader parent = _blockTree.FindHeader(header.ParentHash, BlockTreeLookupOptions.None);
+                            if (parent != null)
                             {
-                                allocation.Refresh();
+                                peerInfo.TotalDifficulty = (parent.TotalDifficulty ?? UInt256.Zero) + header.Difficulty;
+                            }
+
+                            peerInfo.IsInitialized = true;
+                            foreach ((SyncPeerAllocation allocation, object _) in _allocations)
+                            {
+                                if (allocation.Current == peerInfo)
+                                {
+                                    allocation.Refresh();
+                                }
                             }
                         }
                     }
+                    finally
+                    {
+                        linkedSource.Dispose();
+                        delaySource.Dispose();
+                    }
                 }, token);
         }
 
diff --git a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
index 7b1444d83..20885757b 100644
--- a/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
+++ b/src/Nethermind/Nethermind.Blockchain/Synchronization/Synchronizer.cs
@@ -264,60 +264,62 @@ namespace Nethermind.Blockchain.Synchronization
                 }
 
                 _peerSyncCancellation = new CancellationTokenSource();
-                var linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token);
-                Task<long> syncProgressTask;
-                switch (_syncMode.Current)
+                using (CancellationTokenSource linkedCancellation = CancellationTokenSource.CreateLinkedTokenSource(_peerSyncCancellation.Token, _syncLoopCancellation.Token))
                 {
-                    case SyncMode.FastBlocks:
-                        syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
-                        break;
-                    case SyncMode.Headers:
-                        syncProgressTask = _syncConfig.DownloadBodiesInFastSync
-                            ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
-                            : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
-                        break;
-                    case SyncMode.StateNodes:
-                        syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
-                        break;
-                    case SyncMode.WaitForProcessor:
-                        syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
-                        break;
-                    case SyncMode.Full:
-                        syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
-                        break;
-                    case SyncMode.NotStarted:
-                        syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
-                        break;
-                    default:
-                        throw new ArgumentOutOfRangeException();
-                }
+                    Task<long> syncProgressTask;
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.FastBlocks:
+                            syncProgressTask = _fastBlockDownloader.Sync(linkedCancellation.Token);
+                            break;
+                        case SyncMode.Headers:
+                            syncProgressTask = _syncConfig.DownloadBodiesInFastSync
+                                ? _blockDownloader.DownloadBlocks(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token, _syncConfig.DownloadReceiptsInFastSync ? BlockDownloader.DownloadOptions.DownloadWithReceipts : BlockDownloader.DownloadOptions.Download)
+                                : _blockDownloader.DownloadHeaders(bestPeer, SyncModeSelector.FullSyncThreshold, linkedCancellation.Token);
+                            break;
+                        case SyncMode.StateNodes:
+                            syncProgressTask = DownloadStateNodes(_syncLoopCancellation.Token);
+                            break;
+                        case SyncMode.WaitForProcessor:
+                            syncProgressTask = Task.Delay(5000).ContinueWith(_ => 0L);
+                            break;
+                        case SyncMode.Full:
+                            syncProgressTask = _blockDownloader.DownloadBlocks(bestPeer, 0, linkedCancellation.Token);
+                            break;
+                        case SyncMode.NotStarted:
+                            syncProgressTask = Task.Delay(1000).ContinueWith(_ => 0L);
+                            break;
+                        default:
+                            throw new ArgumentOutOfRangeException();
+                    }
 
-                switch (_syncMode.Current)
-                {
-                    case SyncMode.WaitForProcessor:
-                        if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
-                        await syncProgressTask;
-                        break;
-                    case SyncMode.NotStarted:
-                        if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
-                        await syncProgressTask;
-                        break;
-                    default:
-                        await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
-                        break;
-                }
+                    switch (_syncMode.Current)
+                    {
+                        case SyncMode.WaitForProcessor:
+                            if (_logger.IsInfo) _logger.Info("Waiting for the block processor to catch up before the next sync round...");
+                            await syncProgressTask;
+                            break;
+                        case SyncMode.NotStarted:
+                            if (_logger.IsInfo) _logger.Info("Waiting for peers to connect before selecting the sync mode...");
+                            await syncProgressTask;
+                            break;
+                        default:
+                            await syncProgressTask.ContinueWith(t => HandleSyncRequestResult(t, bestPeer));
+                            break;
+                    }
                 
-                if (syncProgressTask.IsCompletedSuccessfully)
-                {
-                    long progress = syncProgressTask.Result;
-                    if (progress == 0 && _blocksSyncAllocation != null)
+                    if (syncProgressTask.IsCompletedSuccessfully)
                     {
-                        _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        long progress = syncProgressTask.Result;
+                        if (progress == 0 && _blocksSyncAllocation != null)
+                        {
+                            _syncPeerPool.ReportNoSyncProgress(_blocksSyncAllocation); // not very fair here - allocation may have changed
+                        }
                     }
+
+                    _blocksSyncAllocation?.FinishSync();
                 }
 
-                _blocksSyncAllocation?.FinishSync();
-                linkedCancellation.Dispose();
                 var source = _peerSyncCancellation;
                 _peerSyncCancellation = null;
                 source?.Dispose();
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
index b2e8159ce..385e4f3b8 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/Eth62ProtocolHandler.cs
@@ -524,8 +524,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
 
             Send(request.Message);
             Task<BlockHeader[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -568,8 +568,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth
             Send(request.Message);
 
             Task<BlockBody[]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
index 84efc3e46..838a69b13 100644
--- a/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
+++ b/src/Nethermind/Nethermind.Network/P2P/Subprotocols/Eth/V63/Eth63ProtocolHandler.cs
@@ -172,8 +172,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
             Task<byte[][]> task = request.CompletionSource.Task;
             
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
@@ -211,8 +211,8 @@ namespace Nethermind.Network.P2P.Subprotocols.Eth.V63
             Send(request.Message);
 
             Task<TxReceipt[][]> task = request.CompletionSource.Task;
-            CancellationTokenSource delayCancellation = new CancellationTokenSource();
-            CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
+            using CancellationTokenSource delayCancellation = new CancellationTokenSource();
+            using CancellationTokenSource compositeCancellation = CancellationTokenSource.CreateLinkedTokenSource(token, delayCancellation.Token);
             var firstTask = await Task.WhenAny(task, Task.Delay(Timeouts.Eth, compositeCancellation.Token));
             if (firstTask.IsCanceled)
             {
diff --git a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
index 00ae0e71d..c27c5cea6 100644
--- a/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
+++ b/src/Nethermind/Nethermind.Network/ProtocolsManager.cs
@@ -101,6 +101,8 @@ namespace Nethermind.Network
                 {
                     if (_logger.IsDebug) _logger.Debug($"{session.Direction} {session.Node:s} disconnected {e.DisconnectType} {e.DisconnectReason}");
                 }
+
+                _syncPeers.TryRemove(session.SessionId, out _);
             }
             
             _sessions.TryRemove(session.SessionId, out session);
