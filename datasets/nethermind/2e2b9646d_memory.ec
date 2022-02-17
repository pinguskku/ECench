commit 2e2b9646d59b9f57133316d0db0a011802912a17
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue May 22 23:14:55 2018 +0100

    remaining update path - removed unnecessary allocations

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index c73e61986..64ee6a44a 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -55,9 +55,9 @@ namespace Nethermind.Db
 
         public DbOnTheRocks(string dbPath, byte[] prefix = null) // TODO: check column families
         {
-            if (!Directory.Exists("db"))
+            if (!Directory.Exists(dbPath))
             {
-                Directory.CreateDirectory("db");
+                Directory.CreateDirectory(dbPath);
             }
 
             // options are based mainly from EtheruemJ at the moment
@@ -182,11 +182,25 @@ namespace Nethermind.Db
                 byte[] prefixedIndex = _prefix == null ? key : Bytes.Concat(_prefix, key);
                 if (_currentBatch != null)
                 {
-                    _currentBatch.Put(prefixedIndex, value);
+                    if (value == null)
+                    {
+                        _currentBatch.Delete(prefixedIndex);
+                    }
+                    else
+                    {
+                        _currentBatch.Put(prefixedIndex, value);
+                    }
                 }
                 else
                 {
-                    _db.Put(prefixedIndex, value);
+                    if (value == null)
+                    {
+                        _db.Remove(prefixedIndex);
+                    }
+                    else
+                    {
+                        _db.Put(prefixedIndex, value);
+                    }
                 }
             }
         }
diff --git a/src/Nethermind/Nethermind.Evm/Nethermind.Evm.csproj b/src/Nethermind/Nethermind.Evm/Nethermind.Evm.csproj
index b172e5c45..d22dccca7 100644
--- a/src/Nethermind/Nethermind.Evm/Nethermind.Evm.csproj
+++ b/src/Nethermind/Nethermind.Evm/Nethermind.Evm.csproj
@@ -13,6 +13,9 @@
     <PackageReference Include="MathNet.Numerics.FSharp" Version="4.4.0" />
   </ItemGroup>
   <ItemGroup>
+    <Reference Include="System.Memory">
+      <HintPath>..\..\..\..\..\Users\tksta\.nuget\packages\system.memory\4.5.0-preview1-26216-02\ref\netstandard2.0\System.Memory.dll</HintPath>
+    </Reference>
     <Reference Include="System.Numerics.Vectors">
       <HintPath>..\..\..\..\..\Users\tksta\.nuget\packages\system.numerics.vectors\4.5.0-preview1-26216-02\ref\netstandard2.0\System.Numerics.Vectors.dll</HintPath>
     </Reference>
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 2cc6fd77f..149580d5e 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -22,7 +22,6 @@ using System.Collections.Generic;
 using System.Diagnostics;
 using System.IO;
 using System.Numerics;
-using System.Threading;
 using System.Threading.Tasks;
 using Nethermind.Blockchain;
 using Nethermind.Blockchain.Difficulty;
@@ -192,7 +191,7 @@ namespace Nethermind.PerfTest
 
             public async Task LoadBlocksFromDb(BigInteger? startBlockNumber, int batchSize = BlockTree.DbLoadBatchSize, int maxBlocksToLoad = int.MaxValue)
             {
-                await _blockTree.LoadBlocksFromDb(startBlockNumber, 100000, 100000);
+                await _blockTree.LoadBlocksFromDb(startBlockNumber, batchSize, maxBlocksToLoad);
             }
 
             public AddBlockResult SuggestBlock(Block block)
@@ -276,6 +275,8 @@ namespace Nethermind.PerfTest
         private static readonly string FullBlocksDbPath = Path.Combine(DbBasePath, DbOnTheRocks.BlocksDbPath);
         private static readonly string FullBlockInfosDbPath = Path.Combine(DbBasePath, DbOnTheRocks.BlockInfosDbPath);
 
+        private const int BlocksToLoad = 100_000;
+
         private static async Task RunRopstenBlocks()
         {
             /* logging & instrumentation */
@@ -362,7 +363,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 1000 == 999)
+                if (args.Block.Number % 10000 == 9999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
@@ -407,13 +408,13 @@ namespace Nethermind.PerfTest
             TaskCompletionSource<object> completionSource = new TaskCompletionSource<object>();
             blockTree.NewBestSuggestedBlock += (sender, args) =>
             {
-                if (args.Block.Number == 100000)
+                if (args.Block.Number == BlocksToLoad)
                 {
                     completionSource.SetResult(null);
                 }
             };
 
-            await Task.WhenAny(completionSource.Task, blockTree.LoadBlocksFromDb(0));
+            await Task.WhenAny(completionSource.Task, blockTree.LoadBlocksFromDb(0, BlocksToLoad, BlocksToLoad));
             blockchainProcessor.Process(blockTree.FindBlock(blockTree.Genesis.Hash, true));
 
             stopwatch.Start();
@@ -435,11 +436,6 @@ namespace Nethermind.PerfTest
             Console.ReadLine();
         }
 
-        private static void BlockTree_NewBestSuggestedBlock(object sender, BlockEventArgs e)
-        {
-            throw new NotImplementedException();
-        }
-
         private static void RunTestCase(string name, ExecutionEnvironment env, int iterations)
         {
             //InMemoryDb db = new InMemoryDb();
diff --git a/src/Nethermind/Nethermind.Store/Nethermind.Store.csproj b/src/Nethermind/Nethermind.Store/Nethermind.Store.csproj
index 65a96488b..598540e3f 100644
--- a/src/Nethermind/Nethermind.Store/Nethermind.Store.csproj
+++ b/src/Nethermind/Nethermind.Store/Nethermind.Store.csproj
@@ -8,4 +8,9 @@
       <Name>Nethermind.Core</Name>
     </ProjectReference>
   </ItemGroup>
+  <ItemGroup>
+    <Reference Include="System.Memory">
+      <HintPath>..\..\..\..\..\Users\tksta\.nuget\packages\system.memory\4.5.0-preview1-26216-02\ref\netstandard2.0\System.Memory.dll</HintPath>
+    </Reference>
+  </ItemGroup>
 </Project>
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeOperation.cs b/src/Nethermind/Nethermind.Store/TreeOperation.cs
index b8c095298..a5b39f0d6 100644
--- a/src/Nethermind/Nethermind.Store/TreeOperation.cs
+++ b/src/Nethermind/Nethermind.Store/TreeOperation.cs
@@ -294,9 +294,10 @@ namespace Nethermind.Store
 
         private byte[] TraverseLeaf(Leaf node)
         {
-            (byte[] shorterPath, byte[] longerPath) = RemainingUpdatePath.Length - node.Path.Length < 0
-                ? (RemainingUpdatePath, node.Path)
-                : (node.Path, RemainingUpdatePath);
+            byte[] remaining = RemainingUpdatePath;
+            (byte[] shorterPath, byte[] longerPath) = remaining.Length - node.Path.Length < 0
+                ? (remaining, node.Path)
+                : (node.Path, remaining);
 
             byte[] shorterPathValue;
             byte[] longerPathValue;
@@ -332,7 +333,7 @@ namespace Nethermind.Store
 
                 if (!Bytes.UnsafeCompare(node.Value, _updateValue))
                 {
-                    Leaf newLeaf = new Leaf(new HexPrefix(true, RemainingUpdatePath), _updateValue);
+                    Leaf newLeaf = new Leaf(new HexPrefix(true, remaining), _updateValue);
                     newLeaf.IsDirty = true;
                     ConnectNodes(newLeaf);
                     return _updateValue;
@@ -389,8 +390,9 @@ namespace Nethermind.Store
 
         private byte[] TraverseExtension(Extension node)
         {
+            byte[] remaining = RemainingUpdatePath;
             int extensionLength = 0;
-            for (int i = 0; i < Math.Min(RemainingUpdatePath.Length, node.Path.Length) && RemainingUpdatePath[i] == node.Path[i]; i++, extensionLength++)
+            for (int i = 0; i < Math.Min(remaining.Length, node.Path.Length) && remaining[i] == node.Path[i]; i++, extensionLength++)
             {
             }
 
@@ -427,16 +429,16 @@ namespace Nethermind.Store
 
             Branch branch = new Branch();
             branch.IsDirty = true;
-            if (extensionLength == RemainingUpdatePath.Length)
+            if (extensionLength == remaining.Length)
             {
                 branch.Value = _updateValue;
             }
             else
             {
-                byte[] path = RemainingUpdatePath.Slice(extensionLength + 1, RemainingUpdatePath.Length - extensionLength - 1);
+                byte[] path = remaining.Slice(extensionLength + 1, remaining.Length - extensionLength - 1);
                 Leaf shortLeaf = new Leaf(new HexPrefix(true, path), _updateValue);
                 shortLeaf.IsDirty = true;
-                branch.Nodes[RemainingUpdatePath[extensionLength]] = new NodeRef(shortLeaf);
+                branch.Nodes[remaining[extensionLength]] = new NodeRef(shortLeaf);
             }
 
             if (node.Path.Length - extensionLength > 1)
commit 2e2b9646d59b9f57133316d0db0a011802912a17
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue May 22 23:14:55 2018 +0100

    remaining update path - removed unnecessary allocations

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index c73e61986..64ee6a44a 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -55,9 +55,9 @@ namespace Nethermind.Db
 
         public DbOnTheRocks(string dbPath, byte[] prefix = null) // TODO: check column families
         {
-            if (!Directory.Exists("db"))
+            if (!Directory.Exists(dbPath))
             {
-                Directory.CreateDirectory("db");
+                Directory.CreateDirectory(dbPath);
             }
 
             // options are based mainly from EtheruemJ at the moment
@@ -182,11 +182,25 @@ namespace Nethermind.Db
                 byte[] prefixedIndex = _prefix == null ? key : Bytes.Concat(_prefix, key);
                 if (_currentBatch != null)
                 {
-                    _currentBatch.Put(prefixedIndex, value);
+                    if (value == null)
+                    {
+                        _currentBatch.Delete(prefixedIndex);
+                    }
+                    else
+                    {
+                        _currentBatch.Put(prefixedIndex, value);
+                    }
                 }
                 else
                 {
-                    _db.Put(prefixedIndex, value);
+                    if (value == null)
+                    {
+                        _db.Remove(prefixedIndex);
+                    }
+                    else
+                    {
+                        _db.Put(prefixedIndex, value);
+                    }
                 }
             }
         }
diff --git a/src/Nethermind/Nethermind.Evm/Nethermind.Evm.csproj b/src/Nethermind/Nethermind.Evm/Nethermind.Evm.csproj
index b172e5c45..d22dccca7 100644
--- a/src/Nethermind/Nethermind.Evm/Nethermind.Evm.csproj
+++ b/src/Nethermind/Nethermind.Evm/Nethermind.Evm.csproj
@@ -13,6 +13,9 @@
     <PackageReference Include="MathNet.Numerics.FSharp" Version="4.4.0" />
   </ItemGroup>
   <ItemGroup>
+    <Reference Include="System.Memory">
+      <HintPath>..\..\..\..\..\Users\tksta\.nuget\packages\system.memory\4.5.0-preview1-26216-02\ref\netstandard2.0\System.Memory.dll</HintPath>
+    </Reference>
     <Reference Include="System.Numerics.Vectors">
       <HintPath>..\..\..\..\..\Users\tksta\.nuget\packages\system.numerics.vectors\4.5.0-preview1-26216-02\ref\netstandard2.0\System.Numerics.Vectors.dll</HintPath>
     </Reference>
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 2cc6fd77f..149580d5e 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -22,7 +22,6 @@ using System.Collections.Generic;
 using System.Diagnostics;
 using System.IO;
 using System.Numerics;
-using System.Threading;
 using System.Threading.Tasks;
 using Nethermind.Blockchain;
 using Nethermind.Blockchain.Difficulty;
@@ -192,7 +191,7 @@ namespace Nethermind.PerfTest
 
             public async Task LoadBlocksFromDb(BigInteger? startBlockNumber, int batchSize = BlockTree.DbLoadBatchSize, int maxBlocksToLoad = int.MaxValue)
             {
-                await _blockTree.LoadBlocksFromDb(startBlockNumber, 100000, 100000);
+                await _blockTree.LoadBlocksFromDb(startBlockNumber, batchSize, maxBlocksToLoad);
             }
 
             public AddBlockResult SuggestBlock(Block block)
@@ -276,6 +275,8 @@ namespace Nethermind.PerfTest
         private static readonly string FullBlocksDbPath = Path.Combine(DbBasePath, DbOnTheRocks.BlocksDbPath);
         private static readonly string FullBlockInfosDbPath = Path.Combine(DbBasePath, DbOnTheRocks.BlockInfosDbPath);
 
+        private const int BlocksToLoad = 100_000;
+
         private static async Task RunRopstenBlocks()
         {
             /* logging & instrumentation */
@@ -362,7 +363,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 1000 == 999)
+                if (args.Block.Number % 10000 == 9999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
@@ -407,13 +408,13 @@ namespace Nethermind.PerfTest
             TaskCompletionSource<object> completionSource = new TaskCompletionSource<object>();
             blockTree.NewBestSuggestedBlock += (sender, args) =>
             {
-                if (args.Block.Number == 100000)
+                if (args.Block.Number == BlocksToLoad)
                 {
                     completionSource.SetResult(null);
                 }
             };
 
-            await Task.WhenAny(completionSource.Task, blockTree.LoadBlocksFromDb(0));
+            await Task.WhenAny(completionSource.Task, blockTree.LoadBlocksFromDb(0, BlocksToLoad, BlocksToLoad));
             blockchainProcessor.Process(blockTree.FindBlock(blockTree.Genesis.Hash, true));
 
             stopwatch.Start();
@@ -435,11 +436,6 @@ namespace Nethermind.PerfTest
             Console.ReadLine();
         }
 
-        private static void BlockTree_NewBestSuggestedBlock(object sender, BlockEventArgs e)
-        {
-            throw new NotImplementedException();
-        }
-
         private static void RunTestCase(string name, ExecutionEnvironment env, int iterations)
         {
             //InMemoryDb db = new InMemoryDb();
diff --git a/src/Nethermind/Nethermind.Store/Nethermind.Store.csproj b/src/Nethermind/Nethermind.Store/Nethermind.Store.csproj
index 65a96488b..598540e3f 100644
--- a/src/Nethermind/Nethermind.Store/Nethermind.Store.csproj
+++ b/src/Nethermind/Nethermind.Store/Nethermind.Store.csproj
@@ -8,4 +8,9 @@
       <Name>Nethermind.Core</Name>
     </ProjectReference>
   </ItemGroup>
+  <ItemGroup>
+    <Reference Include="System.Memory">
+      <HintPath>..\..\..\..\..\Users\tksta\.nuget\packages\system.memory\4.5.0-preview1-26216-02\ref\netstandard2.0\System.Memory.dll</HintPath>
+    </Reference>
+  </ItemGroup>
 </Project>
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeOperation.cs b/src/Nethermind/Nethermind.Store/TreeOperation.cs
index b8c095298..a5b39f0d6 100644
--- a/src/Nethermind/Nethermind.Store/TreeOperation.cs
+++ b/src/Nethermind/Nethermind.Store/TreeOperation.cs
@@ -294,9 +294,10 @@ namespace Nethermind.Store
 
         private byte[] TraverseLeaf(Leaf node)
         {
-            (byte[] shorterPath, byte[] longerPath) = RemainingUpdatePath.Length - node.Path.Length < 0
-                ? (RemainingUpdatePath, node.Path)
-                : (node.Path, RemainingUpdatePath);
+            byte[] remaining = RemainingUpdatePath;
+            (byte[] shorterPath, byte[] longerPath) = remaining.Length - node.Path.Length < 0
+                ? (remaining, node.Path)
+                : (node.Path, remaining);
 
             byte[] shorterPathValue;
             byte[] longerPathValue;
@@ -332,7 +333,7 @@ namespace Nethermind.Store
 
                 if (!Bytes.UnsafeCompare(node.Value, _updateValue))
                 {
-                    Leaf newLeaf = new Leaf(new HexPrefix(true, RemainingUpdatePath), _updateValue);
+                    Leaf newLeaf = new Leaf(new HexPrefix(true, remaining), _updateValue);
                     newLeaf.IsDirty = true;
                     ConnectNodes(newLeaf);
                     return _updateValue;
@@ -389,8 +390,9 @@ namespace Nethermind.Store
 
         private byte[] TraverseExtension(Extension node)
         {
+            byte[] remaining = RemainingUpdatePath;
             int extensionLength = 0;
-            for (int i = 0; i < Math.Min(RemainingUpdatePath.Length, node.Path.Length) && RemainingUpdatePath[i] == node.Path[i]; i++, extensionLength++)
+            for (int i = 0; i < Math.Min(remaining.Length, node.Path.Length) && remaining[i] == node.Path[i]; i++, extensionLength++)
             {
             }
 
@@ -427,16 +429,16 @@ namespace Nethermind.Store
 
             Branch branch = new Branch();
             branch.IsDirty = true;
-            if (extensionLength == RemainingUpdatePath.Length)
+            if (extensionLength == remaining.Length)
             {
                 branch.Value = _updateValue;
             }
             else
             {
-                byte[] path = RemainingUpdatePath.Slice(extensionLength + 1, RemainingUpdatePath.Length - extensionLength - 1);
+                byte[] path = remaining.Slice(extensionLength + 1, remaining.Length - extensionLength - 1);
                 Leaf shortLeaf = new Leaf(new HexPrefix(true, path), _updateValue);
                 shortLeaf.IsDirty = true;
-                branch.Nodes[RemainingUpdatePath[extensionLength]] = new NodeRef(shortLeaf);
+                branch.Nodes[remaining[extensionLength]] = new NodeRef(shortLeaf);
             }
 
             if (node.Path.Length - extensionLength > 1)
