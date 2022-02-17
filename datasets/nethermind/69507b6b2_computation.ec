commit 69507b6b2820e9b9b22a37e2f30b67694baaf691
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sun Mar 17 06:38:58 2019 +0000

    more memory improvements

diff --git a/src/Nethermind/Nethermind.Network.Test/PeerComparerTests.cs b/src/Nethermind/Nethermind.Network.Test/PeerComparerTests.cs
new file mode 100644
index 000000000..d990b3c17
--- /dev/null
+++ b/src/Nethermind/Nethermind.Network.Test/PeerComparerTests.cs
@@ -0,0 +1,81 @@
+/*
+ * Copyright (c) 2018 Demerzel Solutions Limited
+ * This file is part of the Nethermind library.
+ *
+ * The Nethermind library is free software: you can redistribute it and/or modify
+ * it under the terms of the GNU Lesser General Public License as published by
+ * the Free Software Foundation, either version 3 of the License, or
+ * (at your option) any later version.
+ *
+ * The Nethermind library is distributed in the hope that it will be useful,
+ * but WITHOUT ANY WARRANTY; without even the implied warranty of
+ * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+ * GNU Lesser General Public License for more details.
+ *
+ * You should have received a copy of the GNU Lesser General Public License
+ * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+ */
+
+using Nethermind.Core.Test.Builders;
+using Nethermind.Stats;
+using Nethermind.Stats.Model;
+using NSubstitute;
+using NUnit.Framework;
+
+namespace Nethermind.Network.Test
+{
+    [TestFixture]
+    public class PeerComparerTests
+    {
+        private INodeStatsManager _statsManager;
+        private PeerManager.PeerComparer _comparer;
+
+        [SetUp]
+        public void SetUp()
+        {
+            _statsManager = Substitute.For<INodeStatsManager>();
+            _comparer = new PeerManager.PeerComparer(_statsManager);
+        }
+
+        [Test]
+        public void Can_sort_by_trusted()
+        {
+            Node a = new Node(TestItem.PublicKeyA, "127.0.0.1", 30303);
+            a.IsTrusted = true;
+            Peer peerA = new Peer(a);
+
+            Node b = new Node(TestItem.PublicKeyB, "127.0.0.1", 30303);
+            Peer peerB = new Peer(b);
+            
+            Node c = new Node(TestItem.PublicKeyC, "127.0.0.1", 30303);
+            Peer peerC = new Peer(c);
+
+            Assert.AreEqual(1, _comparer.Compare(peerA, peerB));
+            Assert.AreEqual(0, _comparer.Compare(peerB, peerC));
+        }
+        
+        [Test]
+        public void Can_sort_by_Reputation()
+        {
+            Node a = new Node(TestItem.PublicKeyA, "127.0.0.1", 30303);
+            Peer peerA = new Peer(a);
+
+            Node b = new Node(TestItem.PublicKeyB, "127.0.0.1", 30303);
+            Peer peerB = new Peer(b);
+            
+            Node c = new Node(TestItem.PublicKeyC, "127.0.0.1", 30303);
+            Peer peerC = new Peer(c);
+
+            _statsManager.GetCurrentReputation(a).Returns(100);
+            _statsManager.GetCurrentReputation(b).Returns(50);
+            _statsManager.GetCurrentReputation(c).Returns(200);
+
+            Assert.AreEqual(1, _comparer.Compare(peerA, peerB));
+            Assert.AreEqual(-1, _comparer.Compare(peerA, peerC));
+            Assert.AreEqual(-1, _comparer.Compare(peerB, peerC));
+            Assert.AreEqual(0, _comparer.Compare(peerA, peerA));
+            Assert.AreEqual(0, _comparer.Compare(peerB, peerB));
+            Assert.AreEqual(0, _comparer.Compare(peerC, peerC));
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Network/PeerManager.cs b/src/Nethermind/Nethermind.Network/PeerManager.cs
index 790a2f77b..959fcef26 100644
--- a/src/Nethermind/Nethermind.Network/PeerManager.cs
+++ b/src/Nethermind/Nethermind.Network/PeerManager.cs
@@ -71,7 +71,6 @@ namespace Nethermind.Network
             ILogManager logManager)
         {
             _logger = logManager.GetClassLogger();
-
             _rlpxPeer = rlpxPeer ?? throw new ArgumentNullException(nameof(rlpxPeer));
             _stats = stats ?? throw new ArgumentNullException(nameof(stats));
             _discoveryApp = discoveryApp ?? throw new ArgumentNullException(nameof(discoveryApp));
@@ -79,9 +78,8 @@ namespace Nethermind.Network
             _peerStorage = peerStorage ?? throw new ArgumentNullException(nameof(peerStorage));
             _peerLoader = peerLoader ?? throw new ArgumentNullException(nameof(peerLoader));
             _peerStorage.StartBatch();
-
-            _stats = stats;
-            _logger = logManager.GetClassLogger();
+            
+            _peerComparer = new PeerComparer(_stats);
         }
 
         private readonly CancellationTokenSource _cancellationTokenSource = new CancellationTokenSource();
@@ -180,6 +178,16 @@ namespace Nethermind.Network
         public IReadOnlyCollection<Peer> ActivePeers => _activePeers.Values.ToList().AsReadOnly();
         public IReadOnlyCollection<Peer> CandidatePeers => _candidatePeers.Values.ToList().AsReadOnly();
 
+        private class CandidateSelection
+        {
+            public List<Peer> PreCandidates { get; } = new List<Peer>();
+            public List<Peer> Candidates { get; } = new List<Peer>();
+            public List<Peer> Incompatible { get; } = new List<Peer>();
+            public Dictionary<ActivePeerSelectionCounter, int> Counters { get; } = new Dictionary<ActivePeerSelectionCounter, int>();
+        }
+
+        private CandidateSelection _currentSelection = new CandidateSelection();
+
         private async Task RunPeerUpdateLoop()
         {
             while (true)
@@ -217,8 +225,8 @@ namespace Nethermind.Network
                 int failedInitialConnect = 0;
                 int connectionRounds = 0;
 
-                var candidateSelection = SelectAndRankCandidates();
-                IReadOnlyCollection<Peer> remainingCandidates = candidateSelection.Candidates;
+                SelectAndRankCandidates();
+                IReadOnlyCollection<Peer> remainingCandidates = _currentSelection.Candidates;
                 if (!remainingCandidates.Any())
                 {
                     continue;
@@ -284,8 +292,8 @@ namespace Nethermind.Network
                     int activePeersCount = _activePeers.Count;
                     if (activePeersCount != _prevActivePeersCount)
                     {
-                        string countersLog = string.Join(", ", candidateSelection.Counters.Select(x => $"{x.Key.ToString()}: {x.Value}"));
-                        _logger.Debug($"RunPeerUpdate | {countersLog}, Incompatible: {GetIncompatibleDesc(candidateSelection.IncompatiblePeers)}, EligibleCandidates: {candidateSelection.Candidates.Count()}, " +
+                        string countersLog = string.Join(", ", _currentSelection.Counters.Select(x => $"{x.Key.ToString()}: {x.Value}"));
+                        _logger.Debug($"RunPeerUpdate | {countersLog}, Incompatible: {GetIncompatibleDesc(_currentSelection.Incompatible)}, EligibleCandidates: {_currentSelection.Candidates.Count()}, " +
                                       $"Tried: {tryCount}, Rounds: {connectionRounds}, Failed initial connect: {failedInitialConnect}, Established initial connect: {newActiveNodes}, " +
                                       $"Current candidate peers: {_candidatePeers.Count}, Current active peers: {_activePeers.Count} " +
                                       $"[InOut: {_activePeers.Count(x => x.Value.OutSession != null && x.Value.InSession != null)} | " +
@@ -335,65 +343,112 @@ namespace Nethermind.Network
             }
         }
 
-        private (IReadOnlyCollection<Peer> Candidates, IDictionary<ActivePeerSelectionCounter, int> Counters, IReadOnlyCollection<Peer> IncompatiblePeers) SelectAndRankCandidates()
+        private void SelectAndRankCandidates()
         {
-            var counters = Enum.GetValues(typeof(ActivePeerSelectionCounter)).OfType<ActivePeerSelectionCounter>().ToDictionary(x => x, y => 0);
+            _currentSelection.PreCandidates.Clear();
+            _currentSelection.Candidates.Clear();
+            _currentSelection.Incompatible.Clear();
+            foreach (ActivePeerSelectionCounter value in Enum.GetValues(typeof(ActivePeerSelectionCounter)))
+            {
+                _currentSelection.Counters[value] = 0;
+            }
+
             var availableActiveCount = _networkConfig.ActivePeersMaxCount - _activePeers.Count;
             if (availableActiveCount <= 0)
             {
-                return (Array.Empty<Peer>(), counters, Array.Empty<Peer>());
+                return;
             }
 
-            var candidatesSnapshot = _candidatePeers.Where(x => !_activePeers.ContainsKey(x.Key)).ToArray();
-            if (!candidatesSnapshot.Any())
+            foreach ((PublicKey key, Peer peer) in _candidatePeers)
             {
-                return (Array.Empty<Peer>(), counters, Array.Empty<Peer>());
+                if (_activePeers.ContainsKey(key))
+                {
+                    continue;
+                }
+                
+                _currentSelection.PreCandidates.Add(peer);
             }
+            
+            if (!_currentSelection.PreCandidates.Any())
+            {
+                return;
+            }
+            
+            _currentSelection.Counters[ActivePeerSelectionCounter.AllNonActiveCandidates] = _currentSelection.PreCandidates.Count;
 
-            counters[ActivePeerSelectionCounter.AllNonActiveCandidates] = candidatesSnapshot.Length;
-
-            List<Peer> candidates = new List<Peer>();
-            List<Peer> incompatiblePeers = new List<Peer>();
-            for (int i = 0; i < candidatesSnapshot.Length; i++)
+            foreach (Peer preCandidate in _currentSelection.PreCandidates)
             {
-                var candidate = candidatesSnapshot[i];
-                if (candidate.Value.Node.Port == 0)
+                if (preCandidate.Node.Port == 0)
                 {
-                    counters[ActivePeerSelectionCounter.FilteredByZeroPort] = counters[ActivePeerSelectionCounter.FilteredByZeroPort] + 1;
+                    _currentSelection.Counters[ActivePeerSelectionCounter.FilteredByZeroPort]++;
                     continue;
                 }
 
-                var delayResult = _stats.IsConnectionDelayed(candidate.Value.Node);
+                var delayResult = _stats.IsConnectionDelayed(preCandidate.Node);
                 if (delayResult.Result)
                 {
                     if (delayResult.DelayReason == NodeStatsEventType.Disconnect)
                     {
-                        counters[ActivePeerSelectionCounter.FilteredByDisconnect] = counters[ActivePeerSelectionCounter.FilteredByDisconnect] + 1;
+                        _currentSelection.Counters[ActivePeerSelectionCounter.FilteredByDisconnect]++;
                     }
                     else if (delayResult.DelayReason == NodeStatsEventType.ConnectionFailed)
                     {
-                        counters[ActivePeerSelectionCounter.FilteredByFailedConnection] = counters[ActivePeerSelectionCounter.FilteredByFailedConnection] + 1;
+                        _currentSelection.Counters[ActivePeerSelectionCounter.FilteredByFailedConnection]++;
                     }
 
                     continue;
                 }
 
-                if (_stats.FindCompatibilityValidationResult(candidate.Value.Node).HasValue)
+                if (_stats.FindCompatibilityValidationResult(preCandidate.Node).HasValue)
                 {
-                    incompatiblePeers.Add(candidate.Value);
+                    _currentSelection.Incompatible.Add(preCandidate);
                     continue;
                 }
 
-                if (!PeerIsDisconnected(candidate.Value))
+                if (!PeerIsDisconnected(preCandidate))
                 {
                     // in transition
                     continue;
                 }
 
-                candidates.Add(candidate.Value);
+                _currentSelection.Candidates.Add(preCandidate);    
             }
+            
+            _currentSelection.Candidates.Sort(_peerComparer);
+        }
+
+        private PeerComparer _peerComparer;
 
-            return (candidates.OrderBy(x => x.Node.IsTrusted).ThenByDescending(x => _stats.GetCurrentReputation(x.Node)).ToList(), counters, incompatiblePeers);
+        public class PeerComparer : IComparer<Peer>
+        {
+            private readonly INodeStatsManager _stats;
+
+            public PeerComparer(INodeStatsManager stats)
+            {
+                _stats = stats;
+            }
+            
+            public int Compare(Peer x, Peer y)
+            {
+                if (x == null)
+                {
+                    return y == null ? 0 : 1;
+                }
+                
+                if (y == null)
+                {
+                    return -1;
+                }
+                
+                int trust = x.Node.IsTrusted.CompareTo(y.Node.IsTrusted);
+                if (trust != 0)
+                {
+                    return trust;
+                }
+                
+                int reputation = _stats.GetCurrentReputation(x.Node).CompareTo(_stats.GetCurrentReputation(y.Node));
+                return reputation;
+            }
         }
 
 //        private void LogPeerEventHistory(Peer peer)
diff --git a/src/Nethermind/Nethermind.Store/StorageTree.cs b/src/Nethermind/Nethermind.Store/StorageTree.cs
index 61ceb60a3..fd8bde8b5 100644
--- a/src/Nethermind/Nethermind.Store/StorageTree.cs
+++ b/src/Nethermind/Nethermind.Store/StorageTree.cs
@@ -16,11 +16,13 @@
  * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
  */
 
+using System;
 using System.Collections.Generic;
 using System.Numerics;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.Dirichlet.Numerics;
 
 namespace Nethermind.Store
 {
@@ -30,13 +32,16 @@ namespace Nethermind.Store
 
         private static readonly int CacheSizeInt = (int)CacheSize;
 
-        private static readonly Dictionary<BigInteger, byte[]> Cache = new Dictionary<BigInteger, byte[]>(CacheSizeInt);
+        private static readonly Dictionary<UInt256, byte[]> Cache = new Dictionary<UInt256, byte[]>(CacheSizeInt);
 
         static StorageTree()
         {
             for (int i = 0; i < CacheSizeInt; i++)
             {
-                Cache[i] = Keccak.Compute(new BigInteger(i).ToBigEndianByteArray(32)).Bytes;
+                UInt256 index = (UInt256)i;
+                Span<byte> span = stackalloc byte[32];
+                index.ToBigEndian(span);
+                Cache[index] = Keccak.Compute(span).Bytes;
             }
         }
 
@@ -47,18 +52,20 @@ namespace Nethermind.Store
         public StorageTree(IDb db, Keccak rootHash) : base(db, rootHash, false)
         {
         }
-
-        private byte[] GetKey(BigInteger index)
+        
+        private byte[] GetKey(UInt256 index)
         {
             if (index < CacheSize)
             {
                 return Cache[index];
             }
 
-            return Keccak.Compute(index.ToBigEndianByteArray(32)).Bytes;
+            Span<byte> span = stackalloc byte[32];
+            index.ToBigEndian(span);
+            return Keccak.Compute(span).Bytes;
         }
-
-        public byte[] Get(BigInteger index)
+        
+        public byte[] Get(UInt256 index)
         {
             byte[] key = GetKey(index);
             byte[] value = Get(key);
@@ -71,7 +78,7 @@ namespace Nethermind.Store
             return rlp.DecodeByteArray();
         }
 
-        public void Set(BigInteger index, byte[] value)
+        public void Set(UInt256 index, byte[] value)
         {
             if (value.IsZero())
             {
