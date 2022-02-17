commit 5d19d52eee5d89a8b5302cda3f47decd364b71f1
Author: Tomasz Kajetan Stańczak <tkstanczak@users.noreply.github.com>
Date:   Wed Jun 17 14:28:52 2020 +0100

    minor sha2 perf improvements (#2031)

diff --git a/src/Nethermind/Cortex.sln b/src/Nethermind/Cortex.sln
index bc5b34bef..8bc040a40 100644
--- a/src/Nethermind/Cortex.sln
+++ b/src/Nethermind/Cortex.sln
@@ -70,10 +70,10 @@ Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Nethermind.Monitoring", "Ne
 EndProject
 Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Nethermind.Core2.Json.Test", "Nethermind.Core2.Json.Test\Nethermind.Core2.Json.Test.csproj", "{359CB477-96DF-4A84-83D6-1A6B8E82410F}"
 EndProject
-Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Nethermind.Core2.Benchmark", "Nethermind.Core2.Benchmark\Nethermind.Core2.Benchmark.csproj", "{2D69E8F4-B946-4424-82C2-C1C0264550AF}"
-EndProject
 Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Nethermind.Ssz.Test", "Nethermind.Ssz.Test\Nethermind.Ssz.Test.csproj", "{D013F1F4-1C24-4ED0-83A5-86E338746104}"
 EndProject
+Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Nethermind.Core2.Cryptography.Benchmark", "Nethermind.Core2.Cryptography.Benchmark\Nethermind.Core2.Cryptography.Benchmark.csproj", "{88DCDFAA-62D7-4E7D-9F02-D3F1F0328585}"
+EndProject
 Global
 	GlobalSection(SolutionConfigurationPlatforms) = preSolution
 		Debug|Any CPU = Debug|Any CPU
@@ -204,14 +204,14 @@ Global
 		{359CB477-96DF-4A84-83D6-1A6B8E82410F}.Debug|Any CPU.Build.0 = Debug|Any CPU
 		{359CB477-96DF-4A84-83D6-1A6B8E82410F}.Release|Any CPU.ActiveCfg = Release|Any CPU
 		{359CB477-96DF-4A84-83D6-1A6B8E82410F}.Release|Any CPU.Build.0 = Release|Any CPU
-		{2D69E8F4-B946-4424-82C2-C1C0264550AF}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
-		{2D69E8F4-B946-4424-82C2-C1C0264550AF}.Debug|Any CPU.Build.0 = Debug|Any CPU
-		{2D69E8F4-B946-4424-82C2-C1C0264550AF}.Release|Any CPU.ActiveCfg = Release|Any CPU
-		{2D69E8F4-B946-4424-82C2-C1C0264550AF}.Release|Any CPU.Build.0 = Release|Any CPU
 		{D013F1F4-1C24-4ED0-83A5-86E338746104}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
 		{D013F1F4-1C24-4ED0-83A5-86E338746104}.Debug|Any CPU.Build.0 = Debug|Any CPU
 		{D013F1F4-1C24-4ED0-83A5-86E338746104}.Release|Any CPU.ActiveCfg = Release|Any CPU
 		{D013F1F4-1C24-4ED0-83A5-86E338746104}.Release|Any CPU.Build.0 = Release|Any CPU
+		{88DCDFAA-62D7-4E7D-9F02-D3F1F0328585}.Debug|Any CPU.ActiveCfg = Debug|Any CPU
+		{88DCDFAA-62D7-4E7D-9F02-D3F1F0328585}.Debug|Any CPU.Build.0 = Debug|Any CPU
+		{88DCDFAA-62D7-4E7D-9F02-D3F1F0328585}.Release|Any CPU.ActiveCfg = Release|Any CPU
+		{88DCDFAA-62D7-4E7D-9F02-D3F1F0328585}.Release|Any CPU.Build.0 = Release|Any CPU
 	EndGlobalSection
 	GlobalSection(NestedProjects) = preSolution
 		{4FFCC84D-DC26-4429-84D4-8809DD52B851} = {0F737A2F-A2C5-4A7E-A225-27F093A4C105}
@@ -228,7 +228,7 @@ Global
 		{00A8C0EC-87A3-4A55-949C-D158B310BB4E} = {4FFCC84D-DC26-4429-84D4-8809DD52B851}
 		{71E07A03-DC28-4FBB-AFAF-5830AE94A335} = {4FFCC84D-DC26-4429-84D4-8809DD52B851}
 		{359CB477-96DF-4A84-83D6-1A6B8E82410F} = {4FFCC84D-DC26-4429-84D4-8809DD52B851}
-		{2D69E8F4-B946-4424-82C2-C1C0264550AF} = {86A6990C-81A6-4D2A-B2D5-269F0905EB6C}
 		{D013F1F4-1C24-4ED0-83A5-86E338746104} = {4FFCC84D-DC26-4429-84D4-8809DD52B851}
+		{88DCDFAA-62D7-4E7D-9F02-D3F1F0328585} = {86A6990C-81A6-4D2A-B2D5-269F0905EB6C}
 	EndGlobalSection
 EndGlobal
diff --git a/src/Nethermind/Nethermind.Core2.Cryptography.Benchmark/Nethermind.Core2.Cryptography.Benchmark.csproj b/src/Nethermind/Nethermind.Core2.Cryptography.Benchmark/Nethermind.Core2.Cryptography.Benchmark.csproj
new file mode 100644
index 000000000..c1cc42141
--- /dev/null
+++ b/src/Nethermind/Nethermind.Core2.Cryptography.Benchmark/Nethermind.Core2.Cryptography.Benchmark.csproj
@@ -0,0 +1,19 @@
+<Project Sdk="Microsoft.NET.Sdk">
+
+    <PropertyGroup>
+        <TargetFramework>netcoreapp3.1</TargetFramework>
+        <OutputType>Exe</OutputType>
+    </PropertyGroup>
+
+    <ItemGroup>
+      <PackageReference Include="BenchmarkDotNet" Version="0.12.1" />
+      <PackageReference Include="NSubstitute" Version="4.2.1" />
+    </ItemGroup>
+
+    <ItemGroup>
+      <ProjectReference Include="..\Nethermind.BeaconNode.Eth1Bridge\Nethermind.BeaconNode.Eth1Bridge.csproj" />
+      <ProjectReference Include="..\Nethermind.Benchmark.Helpers\Nethermind.Benchmark.Helpers.csproj" />
+      <ProjectReference Include="..\Nethermind.Core2.Cryptography\Nethermind.Core2.Cryptography.csproj" />
+    </ItemGroup>
+
+</Project>
diff --git a/src/Nethermind/Nethermind.Core2.Cryptography.Benchmark/Program.cs b/src/Nethermind/Nethermind.Core2.Cryptography.Benchmark/Program.cs
new file mode 100644
index 000000000..c6430b690
--- /dev/null
+++ b/src/Nethermind/Nethermind.Core2.Cryptography.Benchmark/Program.cs
@@ -0,0 +1,28 @@
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
+
+using BenchmarkDotNet.Running;
+
+namespace Nethermind.Core2.Cryptography.Benchmark
+{
+    public static class Program
+    {
+        public static void Main(string[] args)
+        {
+            BenchmarkRunner.Run<Sha256Benchmark>();
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Core2.Cryptography.Benchmark/Sha256Benchmark.cs b/src/Nethermind/Nethermind.Core2.Cryptography.Benchmark/Sha256Benchmark.cs
new file mode 100644
index 000000000..809d9ab99
--- /dev/null
+++ b/src/Nethermind/Nethermind.Core2.Cryptography.Benchmark/Sha256Benchmark.cs
@@ -0,0 +1,34 @@
+using System.Security.Cryptography;
+using BenchmarkDotNet.Attributes;
+using BenchmarkDotNet.Jobs;
+using Nethermind.Core2.Crypto;
+
+namespace Nethermind.Core2.Cryptography.Benchmark
+{
+    [SimpleJob(RuntimeMoniker.NetCoreApp31)]
+    [MemoryDiagnoser]
+    public class Sha256Benchmark
+    {
+        private SHA256 _system = SHA256.Create();
+
+        private byte[] _bytes = new byte[32]
+        {
+            1,2,3,4,5,6,7,8,
+            1,2,3,4,5,6,7,8,
+            1,2,3,4,5,6,7,8,
+            1,2,3,4,5,6,7,8,
+        };
+
+        [Benchmark(Baseline = true)]
+        public byte[] Current()
+        {
+            return Sha256.ComputeBytes(_bytes);
+        }
+
+        [Benchmark]
+        public byte[] New()
+        {
+            return _system.ComputeHash(_bytes);
+        }
+    }
+}
diff --git a/src/Nethermind/Nethermind.HashLib/Extensions/Converters.cs b/src/Nethermind/Nethermind.HashLib/Extensions/Converters.cs
index 831c8dd62..d25e275e8 100644
--- a/src/Nethermind/Nethermind.HashLib/Extensions/Converters.cs
+++ b/src/Nethermind/Nethermind.HashLib/Extensions/Converters.cs
@@ -14,7 +14,9 @@
 //  You should have received a copy of the GNU Lesser General Public License
 //  along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
 
+using Nethermind.HashLib.Crypto;
 using System;
+using System.Buffers.Binary;
 using System.Diagnostics;
 using System.Text;
 
@@ -26,47 +28,47 @@ namespace Nethermind.HashLib.Extensions
         public static byte[] ConvertToBytes(object a_in)
         {
             if (a_in is byte)
-                return new byte[] { (byte)a_in };
+                return new byte[] {(byte) a_in};
             else if (a_in is short)
-                return BitConverter.GetBytes((short)a_in);
+                return BitConverter.GetBytes((short) a_in);
             else if (a_in is ushort)
-                return BitConverter.GetBytes((ushort)a_in);
+                return BitConverter.GetBytes((ushort) a_in);
             else if (a_in is char)
-                return BitConverter.GetBytes((char)a_in);
+                return BitConverter.GetBytes((char) a_in);
             else if (a_in is int)
-                return BitConverter.GetBytes((int)a_in);
+                return BitConverter.GetBytes((int) a_in);
             else if (a_in is uint)
-                return BitConverter.GetBytes((uint)a_in);
+                return BitConverter.GetBytes((uint) a_in);
             else if (a_in is long)
-                return BitConverter.GetBytes((long)a_in);
+                return BitConverter.GetBytes((long) a_in);
             else if (a_in is ulong)
-                return BitConverter.GetBytes((ulong)a_in);
+                return BitConverter.GetBytes((ulong) a_in);
             else if (a_in is float)
-                return BitConverter.GetBytes((float)a_in);
+                return BitConverter.GetBytes((float) a_in);
             else if (a_in is double)
-                return BitConverter.GetBytes((double)a_in);
+                return BitConverter.GetBytes((double) a_in);
             else if (a_in is string)
-                return ConvertStringToBytes((string)a_in);
+                return ConvertStringToBytes((string) a_in);
             else if (a_in is byte[])
-                return (byte[])((byte[])a_in).Clone();
+                return (byte[]) ((byte[]) a_in).Clone();
             else if (a_in.GetType().IsArray && a_in.GetType().GetElementType() == typeof(short))
-                return ConvertShortsToBytes((short[])a_in);
+                return ConvertShortsToBytes((short[]) a_in);
             else if (a_in.GetType().IsArray && a_in.GetType().GetElementType() == typeof(ushort))
-                return ConvertUShortsToBytes((ushort[])a_in);
+                return ConvertUShortsToBytes((ushort[]) a_in);
             else if (a_in is char[])
-                return ConvertCharsToBytes((char[])a_in);
+                return ConvertCharsToBytes((char[]) a_in);
             else if (a_in.GetType().IsArray && a_in.GetType().GetElementType() == typeof(int))
-                return ConvertIntsToBytes((int[])a_in);
+                return ConvertIntsToBytes((int[]) a_in);
             else if (a_in.GetType().IsArray && a_in.GetType().GetElementType() == typeof(uint))
-                return ConvertUIntsToBytes((uint[])a_in);
+                return ConvertUIntsToBytes((uint[]) a_in);
             else if (a_in.GetType().IsArray && a_in.GetType().GetElementType() == typeof(long))
-                return ConvertLongsToBytes((long[])a_in);
+                return ConvertLongsToBytes((long[]) a_in);
             else if (a_in.GetType().IsArray && a_in.GetType().GetElementType() == typeof(ulong))
-                return ConvertULongsToBytes((ulong[])a_in);
+                return ConvertULongsToBytes((ulong[]) a_in);
             else if (a_in is float[])
-                return ConvertFloatsToBytes((float[])a_in);
+                return ConvertFloatsToBytes((float[]) a_in);
             else if (a_in is double[])
-                return ConvertDoublesToBytes((double[])a_in);
+                return ConvertDoublesToBytes((double[]) a_in);
             else
                 throw new ArgumentException();
         }
@@ -124,11 +126,13 @@ namespace Nethermind.HashLib.Extensions
 
             for (int i = a_index_out; a_length > 0; a_length -= 4)
             {
-                a_result[i++] =
-                    ((uint)a_in[a_index++] << 24) |
-                    ((uint)a_in[a_index++] << 16) |
-                    ((uint)a_in[a_index++] << 8) |
-                    a_in[a_index++];
+                a_result[i] = BinaryPrimitives.ReadUInt32BigEndian(a_in.AsSpan(a_index, 4));
+                i += 4;
+                // a_result[i++] =
+                //     ((uint) a_in[a_index++] << 24) |
+                //     ((uint) a_in[a_index++] << 16) |
+                //     ((uint) a_in[a_index++] << 8) |
+                //     a_in[a_index++];
             }
         }
 
@@ -138,11 +142,14 @@ namespace Nethermind.HashLib.Extensions
 
             for (int i = a_index_out; a_length > 0; a_length -= 4)
             {
-                a_result[i++] =
-                    ((uint)a_in[a_index++] << 24) |
-                    ((uint)a_in[a_index++] << 16) |
-                    ((uint)a_in[a_index++] << 8) |
-                    a_in[a_index++];
+                a_result[i] = BinaryPrimitives.ReadUInt32BigEndian(a_in.Slice(a_index, 4));
+                i ++;
+                a_index += 4;
+                // a_result[i++] =
+                //     ((uint)a_in[a_index++] << 24) |
+                //     ((uint)a_in[a_index++] << 16) |
+                //     ((uint)a_in[a_index++] << 8) |
+                //     a_in[a_index++];
             }
         }
 
@@ -151,13 +158,13 @@ namespace Nethermind.HashLib.Extensions
             Debug.Assert(a_index >= 0);
             Debug.Assert(a_index + 8 <= a_in.Length);
 
-            return ((ulong)a_in[a_index++] << 56) |
-                   ((ulong)a_in[a_index++] << 48) |
-                   ((ulong)a_in[a_index++] << 40) |
-                   ((ulong)a_in[a_index++] << 32) |
-                   ((ulong)a_in[a_index++] << 24) |
-                   ((ulong)a_in[a_index++] << 16) |
-                   ((ulong)a_in[a_index++] << 8) |
+            return ((ulong) a_in[a_index++] << 56) |
+                   ((ulong) a_in[a_index++] << 48) |
+                   ((ulong) a_in[a_index++] << 40) |
+                   ((ulong) a_in[a_index++] << 32) |
+                   ((ulong) a_in[a_index++] << 24) |
+                   ((ulong) a_in[a_index++] << 16) |
+                   ((ulong) a_in[a_index++] << 8) |
                    a_in[a_index];
         }
 
@@ -174,9 +181,9 @@ namespace Nethermind.HashLib.Extensions
             Debug.Assert(a_index >= 0);
             Debug.Assert(a_index + 4 <= a_in.Length);
 
-            return ((uint)a_in[a_index++] << 24) |
-                   ((uint)a_in[a_index++] << 16) |
-                   ((uint)a_in[a_index++] << 8) |
+            return ((uint) a_in[a_index++] << 24) |
+                   ((uint) a_in[a_index++] << 16) |
+                   ((uint) a_in[a_index++] << 8) |
                    a_in[a_index];
         }
 
@@ -185,10 +192,10 @@ namespace Nethermind.HashLib.Extensions
             Debug.Assert(a_index >= 0);
             Debug.Assert(a_index + 4 <= a_in.Length);
 
-            return (uint)a_in[a_index++] |
-                   ((uint)a_in[a_index++] << 8) |
-                   ((uint)a_in[a_index++] << 16) |
-                   ((uint)a_in[a_index] << 24);
+            return (uint) a_in[a_index++] |
+                   ((uint) a_in[a_index++] << 8) |
+                   ((uint) a_in[a_index++] << 16) |
+                   ((uint) a_in[a_index] << 24);
         }
 
         public static ulong[] ConvertBytesToULongsSwapOrder(byte[] a_in, int a_index, int a_length)
@@ -207,14 +214,14 @@ namespace Nethermind.HashLib.Extensions
             for (int i = 0; a_length > 0; a_length -= 8)
             {
                 a_out[i++] =
-                    (((ulong)a_in[a_index++] << 56) |
-                    ((ulong)a_in[a_index++] << 48) |
-                    ((ulong)a_in[a_index++] << 40) |
-                    ((ulong)a_in[a_index++] << 32) |
-                    ((ulong)a_in[a_index++] << 24) |
-                    ((ulong)a_in[a_index++] << 16) |
-                    ((ulong)a_in[a_index++] << 8) |
-                    ((ulong)a_in[a_index++]));
+                    (((ulong) a_in[a_index++] << 56) |
+                     ((ulong) a_in[a_index++] << 48) |
+                     ((ulong) a_in[a_index++] << 40) |
+                     ((ulong) a_in[a_index++] << 32) |
+                     ((ulong) a_in[a_index++] << 24) |
+                     ((ulong) a_in[a_index++] << 16) |
+                     ((ulong) a_in[a_index++] << 8) |
+                     ((ulong) a_in[a_index++]));
             }
         }
 
@@ -229,10 +236,12 @@ namespace Nethermind.HashLib.Extensions
 
             for (int j = 0; a_length > 0; a_length--, a_index++)
             {
-                result[j++] = (byte)(a_in[a_index] >> 24);
-                result[j++] = (byte)(a_in[a_index] >> 16);
-                result[j++] = (byte)(a_in[a_index] >> 8);
-                result[j++] = (byte)a_in[a_index];
+                BinaryPrimitives.WriteUInt32BigEndian(result.AsSpan(j, 4), a_in[a_index]);
+                j += 4;
+                //result[j++] = (byte)(a_in[a_index] >> 24);
+                //result[j++] = (byte)(a_in[a_index] >> 16);
+                //result[j++] = (byte)(a_in[a_index] >> 8);
+                //result[j++] = (byte)a_in[a_index];
             }
 
             return result;
@@ -274,14 +283,14 @@ namespace Nethermind.HashLib.Extensions
 
             for (int j = 0; a_length > 0; a_length--, a_index++)
             {
-                result[j++] = (byte)(a_in[a_index] >> 56);
-                result[j++] = (byte)(a_in[a_index] >> 48);
-                result[j++] = (byte)(a_in[a_index] >> 40);
-                result[j++] = (byte)(a_in[a_index] >> 32);
-                result[j++] = (byte)(a_in[a_index] >> 24);
-                result[j++] = (byte)(a_in[a_index] >> 16);
-                result[j++] = (byte)(a_in[a_index] >> 8);
-                result[j++] = (byte)a_in[a_index];
+                result[j++] = (byte) (a_in[a_index] >> 56);
+                result[j++] = (byte) (a_in[a_index] >> 48);
+                result[j++] = (byte) (a_in[a_index] >> 40);
+                result[j++] = (byte) (a_in[a_index] >> 32);
+                result[j++] = (byte) (a_in[a_index] >> 24);
+                result[j++] = (byte) (a_in[a_index] >> 16);
+                result[j++] = (byte) (a_in[a_index] >> 8);
+                result[j++] = (byte) a_in[a_index];
             }
 
             return result;
@@ -319,28 +328,29 @@ namespace Nethermind.HashLib.Extensions
         {
             Debug.Assert(a_index + 8 <= a_out.Length);
 
-            a_out[a_index++] = (byte)(a_in >> 56);
-            a_out[a_index++] = (byte)(a_in >> 48);
-            a_out[a_index++] = (byte)(a_in >> 40);
-            a_out[a_index++] = (byte)(a_in >> 32);
-            a_out[a_index++] = (byte)(a_in >> 24);
-            a_out[a_index++] = (byte)(a_in >> 16);
-            a_out[a_index++] = (byte)(a_in >> 8);
-            a_out[a_index++] = (byte)a_in;
+            a_out[a_index++] = (byte) (a_in >> 56);
+            a_out[a_index++] = (byte) (a_in >> 48);
+            a_out[a_index++] = (byte) (a_in >> 40);
+            a_out[a_index++] = (byte) (a_in >> 32);
+            a_out[a_index++] = (byte) (a_in >> 24);
+            a_out[a_index++] = (byte) (a_in >> 16);
+            a_out[a_index++] = (byte) (a_in >> 8);
+            a_out[a_index++] = (byte) a_in;
         }
-        
+
         public static void ConvertULongToBytesSwapOrder(ulong a_in, Span<byte> a_out, int a_index)
         {
             Debug.Assert(a_index + 8 <= a_out.Length);
+            BinaryPrimitives.WriteUInt64BigEndian(a_out.Slice(a_index, 8), a_in);
 
-            a_out[a_index++] = (byte)(a_in >> 56);
-            a_out[a_index++] = (byte)(a_in >> 48);
-            a_out[a_index++] = (byte)(a_in >> 40);
-            a_out[a_index++] = (byte)(a_in >> 32);
-            a_out[a_index++] = (byte)(a_in >> 24);
-            a_out[a_index++] = (byte)(a_in >> 16);
-            a_out[a_index++] = (byte)(a_in >> 8);
-            a_out[a_index++] = (byte)a_in;
+            //a_out[a_index++] = (byte)(a_in >> 56);
+            //a_out[a_index++] = (byte)(a_in >> 48);
+            //a_out[a_index++] = (byte)(a_in >> 40);
+            //a_out[a_index++] = (byte)(a_in >> 32);
+            //a_out[a_index++] = (byte)(a_in >> 24);
+            //a_out[a_index++] = (byte)(a_in >> 16);
+            //a_out[a_index++] = (byte)(a_in >> 8);
+            //a_out[a_index++] = (byte)a_in;
         }
 
         public static byte[] ConvertStringToBytes(string a_in)
@@ -468,7 +478,7 @@ namespace Nethermind.HashLib.Extensions
             {
                 Check(a_in, 1, 4);
 
-                string[] ar = BitConverter.ToString(a_in).ToUpper().Split(new char[] { '-' });
+                string[] ar = BitConverter.ToString(a_in).ToUpper().Split(new char[] {'-'});
 
                 hex = "";
 
@@ -512,7 +522,7 @@ namespace Nethermind.HashLib.Extensions
         }
 
         [Conditional("DEBUG")]
-        private static void Check<I, O>(I[] a_in, int a_in_size, O[] a_result, int a_out_size, int a_index_in, int a_length, 
+        private static void Check<I, O>(I[] a_in, int a_in_size, O[] a_result, int a_out_size, int a_index_in, int a_length,
             int a_index_out)
         {
             Debug.Assert((a_length * a_in_size % a_out_size) == 0);
@@ -531,8 +541,8 @@ namespace Nethermind.HashLib.Extensions
 
             Debug.Assert(a_index_out + a_result.Length >= (a_length / a_out_size));
         }
-        
-        private static void Check<I, O>(ReadOnlySpan<I> a_in, int a_in_size, Span<O> a_result, int a_out_size, int a_index_in, int a_length, 
+
+        private static void Check<I, O>(ReadOnlySpan<I> a_in, int a_in_size, Span<O> a_result, int a_out_size, int a_index_in, int a_length,
             int a_index_out)
         {
             Debug.Assert((a_length * a_in_size % a_out_size) == 0);
