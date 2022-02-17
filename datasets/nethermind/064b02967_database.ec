commit 064b0296756b20212edef71d477fbea3feb5e659
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Thu May 10 20:19:05 2018 +0100

    huge memory fix (db snapshots)

diff --git a/src/Nethermind/Nethermind.Db/RocksDbProvider.cs b/src/Nethermind/Nethermind.Db/RocksDbProvider.cs
index 4f764d781..cfa99f6a9 100644
--- a/src/Nethermind/Nethermind.Db/RocksDbProvider.cs
+++ b/src/Nethermind/Nethermind.Db/RocksDbProvider.cs
@@ -64,24 +64,23 @@ namespace Nethermind.Db
         
         private readonly ILogger _logger;
 
-        private readonly Stack<Dictionary<ISnapshotableDb, int>> _snapshots = new Stack<Dictionary<ISnapshotableDb, int>>();
+        internal Stack<Dictionary<ISnapshotableDb, int>> Snapshots { get; } = new Stack<Dictionary<ISnapshotableDb, int>>();
 
         public RocksDbProvider(ILogger logger)
         {
             _logger = logger;
-            _snapshots.Push(new Dictionary<ISnapshotableDb, int>());
         }
 
         public void Restore(int snapshot)
         {
-            if(_logger.IsDebugEnabled) _logger.Debug($"Restoring all DBs to {snapshot}");
+            if (_logger.IsDebugEnabled) _logger.Debug($"Restoring all DBs to {snapshot}");
 
-            while (_snapshots.Count - 2 != snapshot)
+            while (Snapshots.Count != snapshot)
             {
-                _snapshots.Pop();
+                Snapshots.Pop();
             }
 
-            Dictionary<ISnapshotableDb, int> dbSnapshots = _snapshots.Peek();
+            Dictionary<ISnapshotableDb, int> dbSnapshots = Snapshots.Pop();
             foreach (ISnapshotableDb db in AllDbs)
             {
                 db.Restore(dbSnapshots.ContainsKey(db) ? dbSnapshots[db] : -1);
@@ -90,12 +89,14 @@ namespace Nethermind.Db
 
         public void Commit(IReleaseSpec spec)
         {
-            if(_logger.IsDebugEnabled) _logger.Debug("Committing all DBs");
+            if (_logger.IsDebugEnabled) _logger.Debug("Committing all DBs");
 
             foreach (ISnapshotableDb db in AllDbs)
             {
                 db.Commit(spec);
             }
+
+            Snapshots.Pop();
         }
 
         public int TakeSnapshot()
@@ -103,13 +104,19 @@ namespace Nethermind.Db
             Dictionary<ISnapshotableDb, int> dbSnapshots = new Dictionary<ISnapshotableDb, int>();
             foreach (ISnapshotableDb db in AllDbs)
             {
-                dbSnapshots.Add(db, db.TakeSnapshot());
+                int dbSnapshot = db.TakeSnapshot();
+                if (dbSnapshot == -1)
+                {
+                    continue;
+                }
+
+                dbSnapshots.Add(db, dbSnapshot);
             }
 
-            _snapshots.Push(dbSnapshots);
+            Snapshots.Push(dbSnapshots);
 
-            int snapshot = _snapshots.Count - 2;
-            if(_logger.IsDebugEnabled) _logger.Debug($"Taking DB snapshot at {snapshot}");
+            int snapshot = Snapshots.Count;
+            if (_logger.IsDebugEnabled) _logger.Debug($"Taking DB snapshot at {snapshot}");
             return snapshot;
         }
     }
diff --git a/src/Nethermind/Nethermind.Evm.Test/MemDbProviderTests.cs b/src/Nethermind/Nethermind.Evm.Test/MemDbProviderTests.cs
new file mode 100644
index 000000000..c2bb4920b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Evm.Test/MemDbProviderTests.cs
@@ -0,0 +1,61 @@
+﻿/*
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
+using Nethermind.Core;
+using Nethermind.Core.Specs;
+using Nethermind.Store;
+using NUnit.Framework;
+
+namespace Nethermind.Evm.Test
+{
+    [TestFixture]
+    public class MemDbProviderTests
+    {
+        [Test]
+        public void Does_not_keep_unnecessary_snapshots()
+        {
+            MemDbProvider provider = new MemDbProvider(NullLogger.Instance);
+            provider.GetOrCreateCodeDb();
+            provider.GetOrCreateStateDb();
+            provider.GetOrCreateStorageDb(Address.Zero);
+            for (int i = 0; i < 1000; i++)
+            {
+                provider.TakeSnapshot();
+                provider.Commit(Olympic.Instance);    
+            }
+            
+            Assert.AreEqual(0, provider.Snapshots.Count);
+        }
+        
+        [Test]
+        public void Can_restore()
+        {
+            MemDbProvider provider = new MemDbProvider(NullLogger.Instance);
+            provider.GetOrCreateCodeDb();
+            provider.GetOrCreateStateDb();
+            provider.GetOrCreateStorageDb(Address.Zero);
+            for (int i = 0; i < 1000; i++)
+            {
+                int snapshot = provider.TakeSnapshot();
+                provider.Restore(snapshot);    
+            }
+            
+            Assert.AreEqual(0, provider.Snapshots.Count);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/MemDbProvider.cs b/src/Nethermind/Nethermind.Store/MemDbProvider.cs
index a08d62f3c..b04f9ac35 100644
--- a/src/Nethermind/Nethermind.Store/MemDbProvider.cs
+++ b/src/Nethermind/Nethermind.Store/MemDbProvider.cs
@@ -62,24 +62,23 @@ namespace Nethermind.Store
         
         private readonly ILogger _logger;
 
-        private readonly Stack<Dictionary<ISnapshotableDb, int>> _snapshots = new Stack<Dictionary<ISnapshotableDb, int>>();
+        internal Stack<Dictionary<ISnapshotableDb, int>> Snapshots { get; } = new Stack<Dictionary<ISnapshotableDb, int>>();
 
         public MemDbProvider(ILogger logger)
         {
             _logger = logger;
-            _snapshots.Push(new Dictionary<ISnapshotableDb, int>());
         }
 
         public void Restore(int snapshot)
         {
             if(_logger.IsDebugEnabled) _logger.Debug($"Restoring all DBs to {snapshot}");
 
-            while (_snapshots.Count - 2 != snapshot)
+            while (Snapshots.Count != snapshot)
             {
-                _snapshots.Pop();
+                Snapshots.Pop();
             }
 
-            Dictionary<ISnapshotableDb, int> dbSnapshots = _snapshots.Peek();
+            Dictionary<ISnapshotableDb, int> dbSnapshots = Snapshots.Pop();
             foreach (ISnapshotableDb db in AllDbs)
             {
                 db.Restore(dbSnapshots.ContainsKey(db) ? dbSnapshots[db] : -1);
@@ -94,6 +93,8 @@ namespace Nethermind.Store
             {
                 db.Commit(spec);
             }
+
+            Snapshots.Pop();
         }
 
         public int TakeSnapshot()
@@ -101,12 +102,18 @@ namespace Nethermind.Store
             Dictionary<ISnapshotableDb, int> dbSnapshots = new Dictionary<ISnapshotableDb, int>();
             foreach (ISnapshotableDb db in AllDbs)
             {
-                dbSnapshots.Add(db, db.TakeSnapshot());
+                int dbSnapshot = db.TakeSnapshot();
+                if (dbSnapshot == -1)
+                {
+                    continue;
+                }
+
+                dbSnapshots.Add(db, dbSnapshot);
             }
 
-            _snapshots.Push(dbSnapshots);
+            Snapshots.Push(dbSnapshots);
 
-            int snapshot = _snapshots.Count - 2;
+            int snapshot = Snapshots.Count;
             if(_logger.IsDebugEnabled) _logger.Debug($"Taking DB snapshot at {snapshot}");
             return snapshot;
         }
