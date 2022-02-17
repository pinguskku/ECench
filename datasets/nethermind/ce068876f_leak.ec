commit ce068876fd91cd885bde15831bbe69d202843b96
Author: Lukasz Rozmej <lukasz.rozmej@gmail.com>
Date:   Mon Mar 29 18:26:13 2021 +0200

    Fix node memory leaks + Add timer abstraction (#2933)
    
    * Fix node memory leaks
    
    * switch to debug logging
    
    * Move to ITimerFactory and add tests
    
    * fix NDM

diff --git a/src/Nethermind/Nethermind.Api/IBasicApi.cs b/src/Nethermind/Nethermind.Api/IBasicApi.cs
index 8a96a1d64..ff8ad4196 100644
--- a/src/Nethermind/Nethermind.Api/IBasicApi.cs
+++ b/src/Nethermind/Nethermind.Api/IBasicApi.cs
@@ -23,6 +23,7 @@ using Nethermind.Blockchain;
 using Nethermind.Config;
 using Nethermind.Core;
 using Nethermind.Core.Specs;
+using Nethermind.Core.Timers;
 using Nethermind.Crypto;
 using Nethermind.Db;
 using Nethermind.KeyStore;
@@ -55,5 +56,6 @@ namespace Nethermind.Api
         ISpecProvider? SpecProvider { get; set; }
         ISyncModeSelector? SyncModeSelector { get; set; } // here for beam sync DB setup
         ITimestamper Timestamper { get; }
+        ITimerFactory TimerFactory { get; }
     }
 }
diff --git a/src/Nethermind/Nethermind.Core/Timers/ITimer.cs b/src/Nethermind/Nethermind.Core/Timers/ITimer.cs
new file mode 100644
index 000000000..27386d06b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Core/Timers/ITimer.cs
@@ -0,0 +1,33 @@
+//  Copyright (c) 2018 Demerzel Solutions Limited
+//  This file is part of the Nethermind library.
+// 
+//  The Nethermind library is free software: you can redistribute it and/or modify
+//  it under the terms of the GNU Lesser General Public License as published by
+//  the Free Software Foundation, either version 3 of the License, or
+//  (at your option) any later version.
+// 
+//  The Nethermind library is distributed in the hope that it will be useful,
+//  but WITHOUT ANY WARRANTY; without even the implied warranty of
+//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+//  GNU Lesser General Public License for more details.
+// 
+//  You should have received a copy of the GNU Lesser General Public License
+//  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+// 
+
+using System;
+using System.Timers;
+
+namespace Nethermind.Core.Timers
+{
+    public interface ITimer : IDisposable
+    {
+        bool AutoReset { get; set; }
+        bool Enabled { get; set; }
+        TimeSpan Interval { get; set; }
+        double IntervalMilliseconds { get; set; }
+        void Start();
+        void Stop();
+        event EventHandler Elapsed;
+    }
+}
diff --git a/src/Nethermind/Nethermind.Core/Timers/ITimerFactory.cs b/src/Nethermind/Nethermind.Core/Timers/ITimerFactory.cs
new file mode 100644
index 000000000..63adcb83e
--- /dev/null
+++ b/src/Nethermind/Nethermind.Core/Timers/ITimerFactory.cs
@@ -0,0 +1,26 @@
+//  Copyright (c) 2018 Demerzel Solutions Limited
+//  This file is part of the Nethermind library.
+// 
+//  The Nethermind library is free software: you can redistribute it and/or modify
+//  it under the terms of the GNU Lesser General Public License as published by
+//  the Free Software Foundation, either version 3 of the License, or
+//  (at your option) any later version.
+// 
+//  The Nethermind library is distributed in the hope that it will be useful,
+//  but WITHOUT ANY WARRANTY; without even the implied warranty of
+//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+//  GNU Lesser General Public License for more details.
+// 
+//  You should have received a copy of the GNU Lesser General Public License
+//  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+// 
+
+using System;
+
+namespace Nethermind.Core.Timers
+{
+    public interface ITimerFactory
+    {
+        ITimer CreateTimer(TimeSpan interval);
+    }
+}
diff --git a/src/Nethermind/Nethermind.Core/Timers/TimerFactory.cs b/src/Nethermind/Nethermind.Core/Timers/TimerFactory.cs
new file mode 100644
index 000000000..c5bfc7e58
--- /dev/null
+++ b/src/Nethermind/Nethermind.Core/Timers/TimerFactory.cs
@@ -0,0 +1,29 @@
+//  Copyright (c) 2018 Demerzel Solutions Limited
+//  This file is part of the Nethermind library.
+// 
+//  The Nethermind library is free software: you can redistribute it and/or modify
+//  it under the terms of the GNU Lesser General Public License as published by
+//  the Free Software Foundation, either version 3 of the License, or
+//  (at your option) any later version.
+// 
+//  The Nethermind library is distributed in the hope that it will be useful,
+//  but WITHOUT ANY WARRANTY; without even the implied warranty of
+//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+//  GNU Lesser General Public License for more details.
+// 
+//  You should have received a copy of the GNU Lesser General Public License
+//  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+// 
+
+using System;
+using System.Timers;
+
+namespace Nethermind.Core.Timers
+{
+    public class TimerFactory : ITimerFactory
+    {
+        public static readonly ITimerFactory Default = new TimerFactory();
+        
+        public ITimer CreateTimer(TimeSpan interval) => new TimerWrapper(new Timer()) {Interval = interval};
+    }
+}
diff --git a/src/Nethermind/Nethermind.Core/Timers/TimerWrapper.cs b/src/Nethermind/Nethermind.Core/Timers/TimerWrapper.cs
new file mode 100644
index 000000000..8ba11908f
--- /dev/null
+++ b/src/Nethermind/Nethermind.Core/Timers/TimerWrapper.cs
@@ -0,0 +1,74 @@
+//  Copyright (c) 2018 Demerzel Solutions Limited
+//  This file is part of the Nethermind library.
+// 
+//  The Nethermind library is free software: you can redistribute it and/or modify
+//  it under the terms of the GNU Lesser General Public License as published by
+//  the Free Software Foundation, either version 3 of the License, or
+//  (at your option) any later version.
+// 
+//  The Nethermind library is distributed in the hope that it will be useful,
+//  but WITHOUT ANY WARRANTY; without even the implied warranty of
+//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+//  GNU Lesser General Public License for more details.
+// 
+//  You should have received a copy of the GNU Lesser General Public License
+//  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+// 
+
+using System;
+using System.Timers;
+
+namespace Nethermind.Core.Timers
+{
+    public class TimerWrapper : ITimer
+    {
+        private readonly Timer _timer;
+
+        public TimerWrapper(Timer timer)
+        {
+            _timer = timer;
+            _timer.Elapsed += OnElapsed;
+        }
+
+        public bool AutoReset
+        {
+            get => _timer.AutoReset;
+            set => _timer.AutoReset = value;
+        }
+        
+        public bool Enabled
+        {
+            get => _timer.Enabled;
+            set => _timer.Enabled = value;
+        }
+        
+        public TimeSpan Interval
+        {
+            get => TimeSpan.FromMilliseconds(_timer.Interval);
+            set => _timer.Interval = value.TotalMilliseconds;
+        }
+
+        public double IntervalMilliseconds
+        {
+            get => _timer.Interval;
+            set => _timer.Interval = value;
+        }
+
+        public void Start() => _timer.Start();
+
+        public void Stop() => _timer.Stop();
+
+        public event EventHandler? Elapsed;
+
+        public void Dispose()
+        {
+            _timer.Elapsed -= OnElapsed;
+            _timer.Dispose();
+        }
+
+        private void OnElapsed(object sender, ElapsedEventArgs e)
+        {
+            Elapsed?.Invoke(sender, e);
+        }
+    }
+}
diff --git a/src/Nethermind/Nethermind.DataMarketplace.Infrastructure/NdmApi.cs b/src/Nethermind/Nethermind.DataMarketplace.Infrastructure/NdmApi.cs
index 274a560eb..511b792f7 100644
--- a/src/Nethermind/Nethermind.DataMarketplace.Infrastructure/NdmApi.cs
+++ b/src/Nethermind/Nethermind.DataMarketplace.Infrastructure/NdmApi.cs
@@ -31,6 +31,7 @@ using Nethermind.Config;
 using Nethermind.Consensus;
 using Nethermind.Core;
 using Nethermind.Core.Specs;
+using Nethermind.Core.Timers;
 using Nethermind.Crypto;
 using Nethermind.DataMarketplace.Channels;
 using Nethermind.DataMarketplace.Consumers.Shared;
@@ -440,6 +441,7 @@ namespace Nethermind.DataMarketplace.Infrastructure
         }
 
         public ITimestamper Timestamper => _nethermindApi.Timestamper;
+        public ITimerFactory TimerFactory => _nethermindApi.TimerFactory;
 
         public ITransactionProcessor? TransactionProcessor
         {
diff --git a/src/Nethermind/Nethermind.DataMarketplace.Subprotocols.Test/NdmSubprotocolTests.cs b/src/Nethermind/Nethermind.DataMarketplace.Subprotocols.Test/NdmSubprotocolTests.cs
index 645fd4f54..99cf88e7c 100644
--- a/src/Nethermind/Nethermind.DataMarketplace.Subprotocols.Test/NdmSubprotocolTests.cs
+++ b/src/Nethermind/Nethermind.DataMarketplace.Subprotocols.Test/NdmSubprotocolTests.cs
@@ -18,6 +18,7 @@ using System.Threading;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
+using Nethermind.Core.Timers;
 using Nethermind.Crypto;
 using Nethermind.DataMarketplace.Channels;
 using Nethermind.DataMarketplace.Consumers.Shared;
@@ -49,7 +50,7 @@ namespace Nethermind.DataMarketplace.Subprotocols.Test
         private void BuildSubprotocol()
         {
             ISession session = Substitute.For<ISession>();
-            INodeStatsManager nodeStatsManager = new NodeStatsManager(LimboLogs.Instance);
+            INodeStatsManager nodeStatsManager = new NodeStatsManager(Substitute.For<ITimerFactory>(), LimboLogs.Instance);
             MessageSerializationService serializationService = new MessageSerializationService();
             serializationService.Register(typeof(HiMessage).Assembly);
             IConsumerService consumerService = Substitute.For<IConsumerService>();
diff --git a/src/Nethermind/Nethermind.Network.Stats/NodeStatsManager.cs b/src/Nethermind/Nethermind.Network.Stats/NodeStatsManager.cs
index 683c146dc..6634db082 100644
--- a/src/Nethermind/Nethermind.Network.Stats/NodeStatsManager.cs
+++ b/src/Nethermind/Nethermind.Network.Stats/NodeStatsManager.cs
@@ -17,12 +17,17 @@
 using System;
 using System.Collections.Concurrent;
 using System.Collections.Generic;
+using System.IO;
+using System.Linq;
+using System.Timers;
+using Nethermind.Core.Caching;
+using Nethermind.Core.Timers;
 using Nethermind.Logging;
 using Nethermind.Stats.Model;
 
 namespace Nethermind.Stats
 {
-    public class NodeStatsManager : INodeStatsManager
+    public class NodeStatsManager : INodeStatsManager, IDisposable
     {
         private class NodeComparer : IEqualityComparer<Node>
         {
@@ -49,10 +54,39 @@ namespace Nethermind.Stats
         
         private readonly ILogger _logger;
         private readonly ConcurrentDictionary<Node, INodeStats> _nodeStats = new ConcurrentDictionary<Node, INodeStats>(new NodeComparer());
+        private readonly ITimer _cleanupTimer;
+        private readonly int _maxCount;
 
-        public NodeStatsManager(ILogManager logManager)
+        public NodeStatsManager(ITimerFactory timerFactory, ILogManager logManager, int maxCount = 10000)
         {
+            _maxCount = maxCount;
             _logger = logManager?.GetClassLogger() ?? throw new ArgumentNullException(nameof(logManager));
+
+            _cleanupTimer = timerFactory.CreateTimer(TimeSpan.FromMinutes(10));
+            _cleanupTimer.Elapsed += CleanupTimerOnElapsed;
+            _cleanupTimer.Start();
+        }
+
+        private void CleanupTimerOnElapsed(object sender, EventArgs e)
+        {
+            int deleteCount = _nodeStats.Count - _maxCount;
+
+            if (deleteCount > 0)
+            {
+                IEnumerable<Node> toDelete = _nodeStats
+                    .OrderBy(n => n.Value.CurrentNodeReputation)
+                    .Select(n => n.Key)
+                    .Take(_nodeStats.Count - _maxCount);
+
+                int i = 0;
+                foreach (Node node in toDelete)
+                {
+                    _nodeStats.TryRemove(node, out _);
+                    i++;
+                }
+                
+                if (_logger.IsDebug) _logger.Debug($"Removed {i} node stats.");
+            }
         }
 
         private INodeStats AddStats(Node node)
@@ -164,5 +198,10 @@ namespace Nethermind.Stats
             INodeStats stats = GetOrAdd(node);
             stats.AddTransferSpeedCaptureEvent(type, value);
         }
+
+        public void Dispose()
+        {
+            _cleanupTimer.Dispose();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.Network.Test/Discovery/DiscoveryManagerTests.cs b/src/Nethermind/Nethermind.Network.Test/Discovery/DiscoveryManagerTests.cs
index 2820e5a4b..656e4451e 100644
--- a/src/Nethermind/Nethermind.Network.Test/Discovery/DiscoveryManagerTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/Discovery/DiscoveryManagerTests.cs
@@ -21,6 +21,7 @@ using System.Threading.Tasks;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
+using Nethermind.Core.Timers;
 using Nethermind.Crypto;
 using Nethermind.Db;
 using Nethermind.Logging;
@@ -78,7 +79,9 @@ namespace Nethermind.Network.Test.Discovery
             _ipResolver = new IPResolver(_networkConfig, logManager);
 
             var evictionManager = new EvictionManager(_nodeTable, logManager);
-            var lifecycleFactory = new NodeLifecycleManagerFactory(_nodeTable, new DiscoveryMessageFactory(_timestamper), evictionManager, new NodeStatsManager(logManager), discoveryConfig, logManager);
+            ITimerFactory timerFactory = Substitute.For<ITimerFactory>();
+            var lifecycleFactory = new NodeLifecycleManagerFactory(_nodeTable, new DiscoveryMessageFactory(_timestamper), evictionManager, 
+                new NodeStatsManager(timerFactory, logManager), discoveryConfig, logManager);
 
             _nodes = new[] {new Node("192.168.1.18", 1), new Node("192.168.1.19", 2)};
 
diff --git a/src/Nethermind/Nethermind.Network.Test/Discovery/NodeLifecycleManagerTests.cs b/src/Nethermind/Nethermind.Network.Test/Discovery/NodeLifecycleManagerTests.cs
index 03d799097..d845fa890 100644
--- a/src/Nethermind/Nethermind.Network.Test/Discovery/NodeLifecycleManagerTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/Discovery/NodeLifecycleManagerTests.cs
@@ -22,6 +22,7 @@ using Nethermind.Config;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
+using Nethermind.Core.Timers;
 using Nethermind.Logging;
 using Nethermind.Network.Config;
 using Nethermind.Network.Discovery;
@@ -93,7 +94,9 @@ namespace Nethermind.Network.Test.Discovery
 
             var evictionManager = new EvictionManager(_nodeTable, logManager);
             _evictionManagerMock = Substitute.For<IEvictionManager>();
-            var lifecycleFactory = new NodeLifecycleManagerFactory(_nodeTable, new DiscoveryMessageFactory(_timestamper), evictionManager, new NodeStatsManager(logManager), discoveryConfig, logManager);
+            ITimerFactory timerFactory = Substitute.For<ITimerFactory>();
+            var lifecycleFactory = new NodeLifecycleManagerFactory(_nodeTable, new DiscoveryMessageFactory(_timestamper), evictionManager, 
+                new NodeStatsManager(timerFactory, logManager), discoveryConfig, logManager);
 
             _udpClient = Substitute.For<IMessageSender>();
 
diff --git a/src/Nethermind/Nethermind.Network.Test/Discovery/NodesLocatorTests.cs b/src/Nethermind/Nethermind.Network.Test/Discovery/NodesLocatorTests.cs
index 223932416..61fdb763d 100644
--- a/src/Nethermind/Nethermind.Network.Test/Discovery/NodesLocatorTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/Discovery/NodesLocatorTests.cs
@@ -21,6 +21,7 @@ using System.Threading;
 using System.Threading.Tasks;
 using Nethermind.Core;
 using Nethermind.Core.Test.Builders;
+using Nethermind.Core.Timers;
 using Nethermind.Db;
 using Nethermind.Logging;
 using Nethermind.Network.Config;
@@ -30,6 +31,7 @@ using Nethermind.Network.Discovery.Messages;
 using Nethermind.Network.Discovery.RoutingTable;
 using Nethermind.Stats;
 using Nethermind.Stats.Model;
+using NSubstitute;
 using NUnit.Framework;
 
 namespace Nethermind.Network.Test.Discovery
@@ -57,7 +59,8 @@ namespace Nethermind.Network.Test.Discovery
                 LimboLogs.Instance);
             DiscoveryMessageFactory messageFactory = new DiscoveryMessageFactory(Timestamper.Default);
             EvictionManager evictionManager = new EvictionManager(_nodeTable, LimboLogs.Instance);
-            NodeStatsManager nodeStatsManager = new NodeStatsManager(LimboLogs.Instance);
+            ITimerFactory timerFactory = Substitute.For<ITimerFactory>();
+            NodeStatsManager nodeStatsManager = new NodeStatsManager(timerFactory, LimboLogs.Instance);
             NodeLifecycleManagerFactory managerFactory =
                 new NodeLifecycleManagerFactory(
                     _nodeTable,
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/P2PProtocolHandlerTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/P2PProtocolHandlerTests.cs
index 729aa5267..c2420aaae 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/P2PProtocolHandlerTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/P2PProtocolHandlerTests.cs
@@ -16,6 +16,7 @@
 
 using System.Linq;
 using Nethermind.Core.Test.Builders;
+using Nethermind.Core.Timers;
 using Nethermind.Logging;
 using Nethermind.Network.P2P;
 using Nethermind.Network.Rlpx;
@@ -52,10 +53,11 @@ namespace Nethermind.Network.Test.P2P
             _session.LocalPort.Returns(ListenPort);
             Node node = new Node("127.0.0.1", 30303, false);
             _session.Node.Returns(node);
+            ITimerFactory timerFactory = Substitute.For<ITimerFactory>();
             return new P2PProtocolHandler(
                 _session,
                 TestItem.PublicKeyA,
-                new NodeStatsManager(LimboLogs.Instance), 
+                new NodeStatsManager(timerFactory, LimboLogs.Instance), 
                 _serializer,
                 LimboLogs.Instance);
         }
diff --git a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V62/Eth62ProtocolHandlerTests.cs b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V62/Eth62ProtocolHandlerTests.cs
index fa15bccaf..b2a849042 100644
--- a/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V62/Eth62ProtocolHandlerTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/P2P/Subprotocols/Eth/V62/Eth62ProtocolHandlerTests.cs
@@ -26,6 +26,7 @@ using Nethermind.Blockchain.Synchronization;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
+using Nethermind.Core.Timers;
 using Nethermind.Logging;
 using Nethermind.Network.P2P;
 using Nethermind.Network.P2P.Subprotocols;
@@ -66,10 +67,11 @@ namespace Nethermind.Network.Test.P2P.Subprotocols.Eth.V62
             _genesisBlock = Build.A.Block.Genesis.TestObject;
             _syncManager.Head.Returns(_genesisBlock.Header);
             _syncManager.Genesis.Returns(_genesisBlock.Header);
+            ITimerFactory timerFactory = Substitute.For<ITimerFactory>();
             _handler = new Eth62ProtocolHandler(
                 _session,
                 _svc,
-                new NodeStatsManager(LimboLogs.Instance),
+                new NodeStatsManager(timerFactory, LimboLogs.Instance),
                 _syncManager,
                 _transactionPool,
                 LimboLogs.Instance);
diff --git a/src/Nethermind/Nethermind.Network.Test/PeerManagerTests.cs b/src/Nethermind/Nethermind.Network.Test/PeerManagerTests.cs
index 03dcd9383..d9e9eb9bf 100644
--- a/src/Nethermind/Nethermind.Network.Test/PeerManagerTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/PeerManagerTests.cs
@@ -25,6 +25,7 @@ using FluentAssertions;
 using Nethermind.Config;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
+using Nethermind.Core.Timers;
 using Nethermind.Crypto;
 using Nethermind.Logging;
 using Nethermind.Network.Config;
@@ -412,7 +413,8 @@ namespace Nethermind.Network.Test
             {
                 RlpxPeer = new RlpxMock(Sessions);
                 DiscoveryApp = Substitute.For<IDiscoveryApp>();
-                Stats = new NodeStatsManager(LimboLogs.Instance);
+                ITimerFactory timerFactory = Substitute.For<ITimerFactory>();
+                Stats = new NodeStatsManager(timerFactory, LimboLogs.Instance);
                 Storage = new InMemoryStorage();
                 PeerLoader = new PeerLoader(new NetworkConfig(), new DiscoveryConfig(), Stats, Storage, LimboLogs.Instance);
                 NetworkConfig = new NetworkConfig();
diff --git a/src/Nethermind/Nethermind.Network.Test/ProtocolsManagerTests.cs b/src/Nethermind/Nethermind.Network.Test/ProtocolsManagerTests.cs
index e59ecd3eb..3b08fab8e 100644
--- a/src/Nethermind/Nethermind.Network.Test/ProtocolsManagerTests.cs
+++ b/src/Nethermind/Nethermind.Network.Test/ProtocolsManagerTests.cs
@@ -23,6 +23,7 @@ using Nethermind.Blockchain;
 using Nethermind.Blockchain.Synchronization;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
+using Nethermind.Core.Timers;
 using Nethermind.Logging;
 using Nethermind.Network.Discovery;
 using Nethermind.Network.P2P;
@@ -92,7 +93,8 @@ namespace Nethermind.Network.Test
                 _localPeer = Substitute.For<IRlpxPeer>();
                 _localPeer.LocalPort.Returns(_localPort);
                 _localPeer.LocalNodeId.Returns(TestItem.PublicKeyA);
-                _nodeStatsManager = new NodeStatsManager(LimboLogs.Instance);
+                ITimerFactory timerFactory = Substitute.For<ITimerFactory>();
+                _nodeStatsManager = new NodeStatsManager(timerFactory, LimboLogs.Instance);
                 _blockTree = Substitute.For<IBlockTree>();
                 _blockTree.ChainId.Returns(1ul);
                 _blockTree.Genesis.Returns(Build.A.Block.Genesis.TestObject.Header);
diff --git a/src/Nethermind/Nethermind.Network.Test/Stats/NodeStatsManagerTests.cs b/src/Nethermind/Nethermind.Network.Test/Stats/NodeStatsManagerTests.cs
new file mode 100644
index 000000000..5681ceaf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Network.Test/Stats/NodeStatsManagerTests.cs
@@ -0,0 +1,59 @@
+//  Copyright (c) 2018 Demerzel Solutions Limited
+//  This file is part of the Nethermind library.
+// 
+//  The Nethermind library is free software: you can redistribute it and/or modify
+//  it under the terms of the GNU Lesser General Public License as published by
+//  the Free Software Foundation, either version 3 of the License, or
+//  (at your option) any later version.
+// 
+//  The Nethermind library is distributed in the hope that it will be useful,
+//  but WITHOUT ANY WARRANTY; without even the implied warranty of
+//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
+//  GNU Lesser General Public License for more details.
+// 
+//  You should have received a copy of the GNU Lesser General Public License
+//  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
+// 
+
+using System;
+using System.Globalization;
+using System.Linq;
+using System.Net;
+using System.Reflection;
+using System.Timers;
+using FluentAssertions;
+using Nethermind.Core.Test.Builders;
+using Nethermind.Core.Timers;
+using Nethermind.Logging;
+using Nethermind.Stats;
+using Nethermind.Stats.Model;
+using NSubstitute;
+using NUnit.Framework;
+
+namespace Nethermind.Network.Test.Stats
+{
+    public class NodeStatsManagerTests
+    {
+        [Test]
+        public void should_remove_excessive_stats()
+        {
+            ITimerFactory timerFactory = Substitute.For<ITimerFactory>();
+            ITimer timer = Substitute.For<ITimer>();
+            timerFactory.CreateTimer(Arg.Any<TimeSpan>()).Returns(timer);
+            
+            var manager = new NodeStatsManager(timerFactory, LimboLogs.Instance, 3);
+            var nodes = TestItem.PublicKeys.Take(3).Select(k => new Node(k, new IPEndPoint(IPAddress.Loopback, 30303))).ToArray();
+            manager.ReportSyncEvent(nodes[0], NodeStatsEventType.SyncStarted);
+            manager.ReportSyncEvent(nodes[1], NodeStatsEventType.SyncStarted);
+            manager.ReportSyncEvent(nodes[2], NodeStatsEventType.SyncStarted);
+            Node removedNode = new Node(TestItem.PublicKeyD, IPEndPoint.Parse("192.168.0.4:30303"));
+            manager.ReportHandshakeEvent(removedNode, ConnectionDirection.In);
+            manager.GetCurrentReputation(removedNode).Should().NotBe(0);
+
+            timer.Elapsed += Raise.Event();
+
+            manager.GetCurrentReputation(removedNode).Should().Be(0);
+            nodes.Select(n => manager.GetCurrentReputation(n)).Should().NotContain(0);
+        }
+    }
+}
diff --git a/src/Nethermind/Nethermind.Network/Discovery/RoutingTable/NodeTable.cs b/src/Nethermind/Nethermind.Network/Discovery/RoutingTable/NodeTable.cs
index 2380dc7e0..c94ea244a 100644
--- a/src/Nethermind/Nethermind.Network/Discovery/RoutingTable/NodeTable.cs
+++ b/src/Nethermind/Nethermind.Network/Discovery/RoutingTable/NodeTable.cs
@@ -17,7 +17,9 @@
 using System;
 using System.Collections.Concurrent;
 using System.Collections.Generic;
+using System.IO;
 using System.Linq;
+using System.Timers;
 using Nethermind.Core.Crypto;
 using Nethermind.Logging;
 using Nethermind.Network.Config;
@@ -31,8 +33,6 @@ namespace Nethermind.Network.Discovery.RoutingTable
         private INetworkConfig _networkConfig;
         private IDiscoveryConfig _discoveryConfig;
         private INodeDistanceCalculator _nodeDistanceCalculator;
-        
-        private ConcurrentDictionary<Keccak, Node> _nodes = new ConcurrentDictionary<Keccak, Node>(); 
 
         public NodeTable(INodeDistanceCalculator nodeDistanceCalculator, IDiscoveryConfig discoveryConfig, INetworkConfig networkConfig, ILogManager logManager)
         {
@@ -59,7 +59,6 @@ namespace Nethermind.Network.Discovery.RoutingTable
             if (_logger.IsTrace) _logger.Trace($"Adding node to NodeTable: {node}");
             int distanceFromMaster = _nodeDistanceCalculator.CalculateDistance(MasterNode.IdHash.Bytes, node.IdHash.Bytes);
             NodeBucket bucket = Buckets[distanceFromMaster > 0 ? distanceFromMaster - 1 : 0];
-            _nodes.AddOrUpdate(node.IdHash, node, (x, y) => node);
             return bucket.AddNode(node);
         }
 
@@ -69,8 +68,6 @@ namespace Nethermind.Network.Discovery.RoutingTable
             
             int distanceFromMaster = _nodeDistanceCalculator.CalculateDistance(MasterNode.IdHash.Bytes, nodeToAdd.IdHash.Bytes);
             NodeBucket bucket = Buckets[distanceFromMaster > 0 ? distanceFromMaster - 1 : 0];
-            _nodes.AddOrUpdate(nodeToAdd.IdHash, nodeToAdd, (x, y) => nodeToAdd);
-            _nodes.TryRemove(nodeToRemove.IdHash, out _);
             bucket.ReplaceNode(nodeToRemove, nodeToAdd);
         }
 
diff --git a/src/Nethermind/Nethermind.Runner/Ethereum/Api/NethermindApi.cs b/src/Nethermind/Nethermind.Runner/Ethereum/Api/NethermindApi.cs
index 2e2e05e2a..e9743f113 100644
--- a/src/Nethermind/Nethermind.Runner/Ethereum/Api/NethermindApi.cs
+++ b/src/Nethermind/Nethermind.Runner/Ethereum/Api/NethermindApi.cs
@@ -33,6 +33,7 @@ using Nethermind.Config;
 using Nethermind.Consensus;
 using Nethermind.Core;
 using Nethermind.Core.Specs;
+using Nethermind.Core.Timers;
 using Nethermind.Crypto;
 using Nethermind.Db;
 using Nethermind.Db.Blooms;
@@ -174,6 +175,7 @@ namespace Nethermind.Runner.Ethereum.Api
         public IStorageProvider? StorageProvider { get; set; }
         public IStaticNodesManager? StaticNodesManager { get; set; }
         public ITimestamper Timestamper { get; } = Core.Timestamper.Default;
+        public ITimerFactory TimerFactory { get; } = Core.Timers.TimerFactory.Default;
         public ITransactionProcessor? TransactionProcessor { get; set; }
         public ITrieStore? TrieStore { get; set; }
         public IReadOnlyTrieStore? ReadOnlyTrieStore { get; set; }
diff --git a/src/Nethermind/Nethermind.Runner/Ethereum/Steps/InitializeNodeStats.cs b/src/Nethermind/Nethermind.Runner/Ethereum/Steps/InitializeNodeStats.cs
index 378413f7c..38e5ea791 100644
--- a/src/Nethermind/Nethermind.Runner/Ethereum/Steps/InitializeNodeStats.cs
+++ b/src/Nethermind/Nethermind.Runner/Ethereum/Steps/InitializeNodeStats.cs
@@ -17,6 +17,7 @@
 using System.Threading;
 using System.Threading.Tasks;
 using Nethermind.Api;
+using Nethermind.Network.Config;
 using Nethermind.Stats;
 
 namespace Nethermind.Runner.Ethereum.Steps
@@ -33,8 +34,12 @@ namespace Nethermind.Runner.Ethereum.Steps
 
         public Task Execute(CancellationToken _)
         {
+            var config = _api.Config<INetworkConfig>();
+            
             // create shared objects between discovery and peer manager
-            _api.NodeStatsManager = new NodeStatsManager(_api.LogManager);
+            NodeStatsManager nodeStatsManager = new(_api.TimerFactory, _api.LogManager, config.MaxCandidatePeerCount);
+            _api.NodeStatsManager = nodeStatsManager;
+            _api.DisposeStack.Push(nodeStatsManager);
 
             return Task.CompletedTask;
         }
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
index b1734fc9a..fb36ff687 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/FastSync/StateSyncFeedTests.cs
@@ -29,6 +29,7 @@ using Nethermind.Core.Crypto;
 using Nethermind.Core.Extensions;
 using Nethermind.Core.Test;
 using Nethermind.Core.Test.Builders;
+using Nethermind.Core.Timers;
 using Nethermind.Db;
 using Nethermind.Int256;
 using Nethermind.Logging;
@@ -41,6 +42,7 @@ using Nethermind.Synchronization.Peers;
 using Nethermind.Synchronization.StateSync;
 using Nethermind.Trie;
 using Nethermind.Trie.Pruning;
+using NSubstitute;
 using NUnit.Framework;
 using BlockTree = Nethermind.Blockchain.BlockTree;
 
@@ -288,7 +290,8 @@ namespace Nethermind.Synchronization.Test.FastSync
             SafeContext ctx = new SafeContext();
             ctx = new SafeContext();
             BlockTree blockTree = Build.A.BlockTree().OfChainLength((int) BlockTree.BestSuggestedHeader.Number).TestObject;
-            ctx.Pool = new SyncPeerPool(blockTree, new NodeStatsManager(LimboLogs.Instance), 25, LimboLogs.Instance);
+            ITimerFactory timerFactory = Substitute.For<ITimerFactory>();
+            ctx.Pool = new SyncPeerPool(blockTree, new NodeStatsManager(timerFactory, LimboLogs.Instance), 25, LimboLogs.Instance);
             ctx.Pool.Start();
             ctx.Pool.AddPeer(syncPeer);
 
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/OldStyleFullSynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/OldStyleFullSynchronizerTests.cs
index ee5403045..4eac977ef 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/OldStyleFullSynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/OldStyleFullSynchronizerTests.cs
@@ -26,6 +26,7 @@ using Nethermind.Blockchain.Validators;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
+using Nethermind.Core.Timers;
 using Nethermind.Db;
 using Nethermind.Logging;
 using Nethermind.Specs;
@@ -59,7 +60,8 @@ namespace Nethermind.Synchronization.Test
             SyncConfig quickConfig = new SyncConfig();
             quickConfig.FastSync = false;
 
-            var stats = new NodeStatsManager(LimboLogs.Instance);
+            ITimerFactory timerFactory = Substitute.For<ITimerFactory>();
+            var stats = new NodeStatsManager(timerFactory, LimboLogs.Instance);
             _pool = new SyncPeerPool(_blockTree, stats, 25, LimboLogs.Instance);
             SyncConfig syncConfig = new SyncConfig();
             SyncProgressResolver resolver = new SyncProgressResolver(
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SyncThreadTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SyncThreadTests.cs
index 46e8c153e..0a2abb44e 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SyncThreadTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SyncThreadTests.cs
@@ -30,6 +30,7 @@ using Nethermind.Consensus;
 using Nethermind.Core;
 using Nethermind.Core.Extensions;
 using Nethermind.Core.Test.Builders;
+using Nethermind.Core.Timers;
 using Nethermind.Crypto;
 using Nethermind.Db;
 using Nethermind.Int256;
@@ -46,6 +47,7 @@ using Nethermind.Synchronization.Peers;
 using Nethermind.Trie.Pruning;
 using Nethermind.TxPool;
 using Nethermind.TxPool.Storages;
+using NSubstitute;
 using NUnit.Framework;
 using BlockTree = Nethermind.Blockchain.BlockTree;
 
@@ -313,7 +315,8 @@ namespace Nethermind.Synchronization.Test
             BlockchainProcessor processor = new(tree, blockProcessor, step, logManager,
                 BlockchainProcessor.Options.Default);
 
-            NodeStatsManager nodeStatsManager = new(logManager);
+            ITimerFactory timerFactory = Substitute.For<ITimerFactory>();
+            NodeStatsManager nodeStatsManager = new(timerFactory, logManager);
             SyncPeerPool syncPeerPool = new(tree, nodeStatsManager, 25, logManager);
 
             StateProvider devState = new(trieStore, codeDb, logManager);
diff --git a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
index 8c395b447..79de7113e 100644
--- a/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
+++ b/src/Nethermind/Nethermind.Synchronization.Test/SynchronizerTests.cs
@@ -27,6 +27,7 @@ using Nethermind.Blockchain.Validators;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Test.Builders;
+using Nethermind.Core.Timers;
 using Nethermind.Db;
 using Nethermind.Int256;
 using Nethermind.Logging;
@@ -42,6 +43,7 @@ using Nethermind.Synchronization.ParallelSync;
 using Nethermind.Synchronization.Peers;
 using Nethermind.Trie.Pruning;
 using Nethermind.TxPool;
+using NSubstitute;
 using NUnit.Framework;
 
 namespace Nethermind.Synchronization.Test
@@ -278,7 +280,8 @@ namespace Nethermind.Synchronization.Test
                 IDb codeDb = dbProvider.CodeDb;
                 MemDb blockInfoDb = new MemDb();
                 BlockTree = new BlockTree(new MemDb(), new MemDb(), blockInfoDb, new ChainLevelInfoRepository(blockInfoDb), new SingleReleaseSpecProvider(Constantinople.Instance, 1), NullBloomStorage.Instance, _logManager);
-                NodeStatsManager stats = new NodeStatsManager(_logManager);
+                ITimerFactory timerFactory = Substitute.For<ITimerFactory>();
+                NodeStatsManager stats = new NodeStatsManager(timerFactory, _logManager);
                 SyncPeerPool = new SyncPeerPool(BlockTree, stats, 25, _logManager);
 
                 SyncProgressResolver syncProgressResolver = new SyncProgressResolver(
