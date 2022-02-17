commit 5663734cf536f85349b1a4cb944dcc4b1f871b96
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Tue Jul 30 11:57:43 2019 +0100

    SignExtend 50x speed no alloc improvement #717

diff --git a/src/Nethermind/Nethermind.Benchmarks/Evm/SignExtend.cs b/src/Nethermind/Nethermind.Benchmarks/Evm/SignExtend.cs
new file mode 100644
index 000000000..6f80239cc
--- /dev/null
+++ b/src/Nethermind/Nethermind.Benchmarks/Evm/SignExtend.cs
@@ -0,0 +1,116 @@
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
+using System;
+using System.Collections;
+using BenchmarkDotNet.Attributes;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Benchmarks.Evm
+{
+    [MemoryDiagnoser]
+    [CoreJob(baseline: true)]
+    public class SignExtend
+    {
+        [GlobalSetup]
+        public void Setup()
+        {
+        }
+
+        private byte[] a = new byte[32]
+        {
+            1, 17, 34, 50, 64, 78, 12, 56, 19, 12,
+            120, 21, 123, 12, 76, 121, 1, 12, 23, 8,
+            120, 21, 123, 12, 76, 121, 1, 12, 23, 8,
+            120, 21
+        };
+        private byte[] b = new byte[32]
+        {
+            120, 21, 123, 12, 76, 121, 1, 12, 23, 8,
+            77, 17, 34, 50, 64, 78, 12, 2, 19, 12,
+            120, 21, 123, 12, 76, 121, 1, 12, 23, 8,
+            55, 255
+        };
+        
+        private byte[] c = new byte[32];
+        
+        [Benchmark(Baseline = true)]
+        public void Current()
+        {
+            int a = 12;
+            Span<byte> localB = this.b.AsSpan();
+            BitArray bits1 = localB.ToBigEndianBitArray256();
+            int bitPosition = Math.Max(0, 248 - 8 * (int)a);
+            bool isSet = bits1[bitPosition];
+            for (int i = 0; i < bitPosition; i++)
+            {
+                bits1[i] = isSet;
+            }
+
+            bits1.ToBytes().CopyTo(c.AsSpan());
+        }
+
+        private readonly byte[] BytesZero32 =
+        {
+            0, 0, 0, 0, 0, 0, 0, 0,
+            0, 0, 0, 0, 0, 0, 0, 0,
+            0, 0, 0, 0, 0, 0, 0, 0,
+            0, 0, 0, 0, 0, 0, 0, 0
+        };
+        
+        private readonly byte[] BytesMax32 =
+        {
+            255, 255, 255, 255, 255, 255, 255, 255,
+            255, 255, 255, 255, 255, 255, 255, 255,
+            255, 255, 255, 255, 255, 255, 255, 255,
+            255, 255, 255, 255, 255, 255, 255, 255
+        };
+        
+        [Benchmark]
+        public void Improved()
+        {
+            int a = 12;
+            Span<byte> localB = b.AsSpan();
+            sbyte sign = (sbyte)localB[31 - a];
+
+            if (sign < 0)
+            {
+                BytesZero32.AsSpan().Slice(0, a - 1).CopyTo(localB.Slice(0, a - 1));
+            }
+            else
+            {
+                BytesMax32.AsSpan().Slice(0, a - 1).CopyTo(localB.Slice(0, a - 1));
+            }
+            
+            localB.CopyTo(c);
+        }
+        
+        [Benchmark]
+        public void Improved2()
+        {
+            int a = 12;
+            Span<byte> localB = b.AsSpan();
+            sbyte sign = (sbyte)localB[31 - a];
+
+            Span<byte> signBytes = sign < 0 ? BytesZero32.AsSpan() : BytesMax32.AsSpan();
+            signBytes.Slice(0, a - 1).CopyTo(b.Slice(0, a - 1));
+            
+            localB.CopyTo(c);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Benchmarks/Program.cs b/src/Nethermind/Nethermind.Benchmarks/Program.cs
index 42a76b62c..cf0e7a45b 100644
--- a/src/Nethermind/Nethermind.Benchmarks/Program.cs
+++ b/src/Nethermind/Nethermind.Benchmarks/Program.cs
@@ -66,7 +66,8 @@ namespace Nethermind.Benchmarks
 //            BenchmarkRunner.Run<RlpEncodeTransaction>();
 //              BenchmarkRunner.Run<RlpEncodeLong>();
 //              BenchmarkRunner.Run<RlpDecodeLong>();
-              BenchmarkRunner.Run<RlpDecodeInt>();
+//              BenchmarkRunner.Run<RlpDecodeInt>();
+              BenchmarkRunner.Run<SignExtend>();
 
 //              BenchmarkRunner.Run<PatriciaTree>();
 //            
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 5e8460680..b5eb9fe15 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -58,6 +58,14 @@ namespace Nethermind.Evm
             0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 0, 0
         };
+        
+        internal readonly byte[] BytesMax32 =
+        {
+            255, 255, 255, 255, 255, 255, 255, 255,
+            255, 255, 255, 255, 255, 255, 255, 255,
+            255, 255, 255, 255, 255, 255, 255, 255,
+            255, 255, 255, 255, 255, 255, 255, 255
+        };
 
         private readonly IBlockhashProvider _blockhashProvider;
         private readonly LruCache<Keccak, CodeInfo> _codeCache = new LruCache<Keccak, CodeInfo>(4 * 1024);
@@ -1101,16 +1109,21 @@ namespace Nethermind.Evm
                             break;
                         }
 
+                        int position = (int)a;
+
                         Span<byte> b = PopBytes(bytesOnStack);
-                        BitArray bits1 = b.ToBigEndianBitArray256();
-                        int bitPosition = Math.Max(0, 248 - 8 * (int)a);
-                        bool isSet = bits1[bitPosition];
-                        for (int i = 0; i < bitPosition; i++)
+                        sbyte sign = (sbyte)b[31 - position];
+
+                        if (sign < 0)
+                        {
+                            BytesZero32.AsSpan().Slice(0, position - 1).CopyTo(b.Slice(0, position - 1));
+                        }
+                        else
                         {
-                            bits1[i] = isSet;
+                            BytesMax32.AsSpan().Slice(0, position - 1).CopyTo(b.Slice(0, position - 1));
                         }
 
-                        PushBytes(bits1.ToBytes(), bytesOnStack);
+                        PushBytes(b, bytesOnStack);
                         break;
                     }
                     case Instruction.LT:
commit 5663734cf536f85349b1a4cb944dcc4b1f871b96
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Tue Jul 30 11:57:43 2019 +0100

    SignExtend 50x speed no alloc improvement #717

diff --git a/src/Nethermind/Nethermind.Benchmarks/Evm/SignExtend.cs b/src/Nethermind/Nethermind.Benchmarks/Evm/SignExtend.cs
new file mode 100644
index 000000000..6f80239cc
--- /dev/null
+++ b/src/Nethermind/Nethermind.Benchmarks/Evm/SignExtend.cs
@@ -0,0 +1,116 @@
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
+using System;
+using System.Collections;
+using BenchmarkDotNet.Attributes;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Benchmarks.Evm
+{
+    [MemoryDiagnoser]
+    [CoreJob(baseline: true)]
+    public class SignExtend
+    {
+        [GlobalSetup]
+        public void Setup()
+        {
+        }
+
+        private byte[] a = new byte[32]
+        {
+            1, 17, 34, 50, 64, 78, 12, 56, 19, 12,
+            120, 21, 123, 12, 76, 121, 1, 12, 23, 8,
+            120, 21, 123, 12, 76, 121, 1, 12, 23, 8,
+            120, 21
+        };
+        private byte[] b = new byte[32]
+        {
+            120, 21, 123, 12, 76, 121, 1, 12, 23, 8,
+            77, 17, 34, 50, 64, 78, 12, 2, 19, 12,
+            120, 21, 123, 12, 76, 121, 1, 12, 23, 8,
+            55, 255
+        };
+        
+        private byte[] c = new byte[32];
+        
+        [Benchmark(Baseline = true)]
+        public void Current()
+        {
+            int a = 12;
+            Span<byte> localB = this.b.AsSpan();
+            BitArray bits1 = localB.ToBigEndianBitArray256();
+            int bitPosition = Math.Max(0, 248 - 8 * (int)a);
+            bool isSet = bits1[bitPosition];
+            for (int i = 0; i < bitPosition; i++)
+            {
+                bits1[i] = isSet;
+            }
+
+            bits1.ToBytes().CopyTo(c.AsSpan());
+        }
+
+        private readonly byte[] BytesZero32 =
+        {
+            0, 0, 0, 0, 0, 0, 0, 0,
+            0, 0, 0, 0, 0, 0, 0, 0,
+            0, 0, 0, 0, 0, 0, 0, 0,
+            0, 0, 0, 0, 0, 0, 0, 0
+        };
+        
+        private readonly byte[] BytesMax32 =
+        {
+            255, 255, 255, 255, 255, 255, 255, 255,
+            255, 255, 255, 255, 255, 255, 255, 255,
+            255, 255, 255, 255, 255, 255, 255, 255,
+            255, 255, 255, 255, 255, 255, 255, 255
+        };
+        
+        [Benchmark]
+        public void Improved()
+        {
+            int a = 12;
+            Span<byte> localB = b.AsSpan();
+            sbyte sign = (sbyte)localB[31 - a];
+
+            if (sign < 0)
+            {
+                BytesZero32.AsSpan().Slice(0, a - 1).CopyTo(localB.Slice(0, a - 1));
+            }
+            else
+            {
+                BytesMax32.AsSpan().Slice(0, a - 1).CopyTo(localB.Slice(0, a - 1));
+            }
+            
+            localB.CopyTo(c);
+        }
+        
+        [Benchmark]
+        public void Improved2()
+        {
+            int a = 12;
+            Span<byte> localB = b.AsSpan();
+            sbyte sign = (sbyte)localB[31 - a];
+
+            Span<byte> signBytes = sign < 0 ? BytesZero32.AsSpan() : BytesMax32.AsSpan();
+            signBytes.Slice(0, a - 1).CopyTo(b.Slice(0, a - 1));
+            
+            localB.CopyTo(c);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Benchmarks/Program.cs b/src/Nethermind/Nethermind.Benchmarks/Program.cs
index 42a76b62c..cf0e7a45b 100644
--- a/src/Nethermind/Nethermind.Benchmarks/Program.cs
+++ b/src/Nethermind/Nethermind.Benchmarks/Program.cs
@@ -66,7 +66,8 @@ namespace Nethermind.Benchmarks
 //            BenchmarkRunner.Run<RlpEncodeTransaction>();
 //              BenchmarkRunner.Run<RlpEncodeLong>();
 //              BenchmarkRunner.Run<RlpDecodeLong>();
-              BenchmarkRunner.Run<RlpDecodeInt>();
+//              BenchmarkRunner.Run<RlpDecodeInt>();
+              BenchmarkRunner.Run<SignExtend>();
 
 //              BenchmarkRunner.Run<PatriciaTree>();
 //            
diff --git a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
index 5e8460680..b5eb9fe15 100644
--- a/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
+++ b/src/Nethermind/Nethermind.Evm/VirtualMachine.cs
@@ -58,6 +58,14 @@ namespace Nethermind.Evm
             0, 0, 0, 0, 0, 0, 0, 0,
             0, 0, 0, 0, 0, 0, 0, 0
         };
+        
+        internal readonly byte[] BytesMax32 =
+        {
+            255, 255, 255, 255, 255, 255, 255, 255,
+            255, 255, 255, 255, 255, 255, 255, 255,
+            255, 255, 255, 255, 255, 255, 255, 255,
+            255, 255, 255, 255, 255, 255, 255, 255
+        };
 
         private readonly IBlockhashProvider _blockhashProvider;
         private readonly LruCache<Keccak, CodeInfo> _codeCache = new LruCache<Keccak, CodeInfo>(4 * 1024);
@@ -1101,16 +1109,21 @@ namespace Nethermind.Evm
                             break;
                         }
 
+                        int position = (int)a;
+
                         Span<byte> b = PopBytes(bytesOnStack);
-                        BitArray bits1 = b.ToBigEndianBitArray256();
-                        int bitPosition = Math.Max(0, 248 - 8 * (int)a);
-                        bool isSet = bits1[bitPosition];
-                        for (int i = 0; i < bitPosition; i++)
+                        sbyte sign = (sbyte)b[31 - position];
+
+                        if (sign < 0)
+                        {
+                            BytesZero32.AsSpan().Slice(0, position - 1).CopyTo(b.Slice(0, position - 1));
+                        }
+                        else
                         {
-                            bits1[i] = isSet;
+                            BytesMax32.AsSpan().Slice(0, position - 1).CopyTo(b.Slice(0, position - 1));
                         }
 
-                        PushBytes(bits1.ToBytes(), bytesOnStack);
+                        PushBytes(b, bytesOnStack);
                         break;
                     }
                     case Instruction.LT:
