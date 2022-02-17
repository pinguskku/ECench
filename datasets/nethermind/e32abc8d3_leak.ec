commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
commit e32abc8d32e4323630a1fc893a222adf5a1b8bc8
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed May 30 18:48:42 2018 +0100

    fixed mempory leak (write batch dispose)

diff --git a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
index 964163b7d..d38b309c1 100644
--- a/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
+++ b/src/Nethermind/Nethermind.Db/DbOnTheRocks.cs
@@ -203,6 +203,7 @@ namespace Nethermind.Db
         public void CommitBatch()
         {
             _db.Write(_currentBatch);
+            _currentBatch.Dispose();
             _currentBatch = null;
         }        
 
diff --git a/src/Nethermind/Nethermind.PerfTest/Program.cs b/src/Nethermind/Nethermind.PerfTest/Program.cs
index 6b2b7f49f..463ab95a4 100644
--- a/src/Nethermind/Nethermind.PerfTest/Program.cs
+++ b/src/Nethermind/Nethermind.PerfTest/Program.cs
@@ -369,7 +369,7 @@ namespace Nethermind.PerfTest
                 }
 
                 totalGas += currentHead.GasUsed;
-                if (args.Block.Number % 10000 == 9999)
+                if (args.Block.Number % 100000 == 99999)
                 {
                     stopwatch.Stop();
                     long ns = 1_000_000_000L * stopwatch.ElapsedTicks / Stopwatch.Frequency;
