commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
commit ada40a0f569bdd0c0edf77a9d8eb1d672fd328fe
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Tue Mar 6 20:44:31 2018 +0000

    ethash performance improvements

diff --git a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
index f8549f5f5..b3d9d7e0d 100644
--- a/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
+++ b/src/Nethermind/Ethereum.PoW.Test/EthashTests.cs
@@ -79,13 +79,13 @@ namespace Ethereum.PoW.Test
 
             // seed is correct
             Ethash ethash = new Ethash();
-            Assert.AreEqual(test.Seed, ethash.GetSeedHash(blockHeader.Number), "seed");
+            Assert.AreEqual(test.Seed, Ethash.GetSeedHash(blockHeader.Number), "seed");
 
-            uint cacheSize = ethash.GetCacheSize(blockHeader.Number);
+            uint cacheSize = Ethash.GetCacheSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.CacheSize, cacheSize, "cache size requested");
 
-            byte[][] cache = ethash.MakeCache(cacheSize, test.Seed.Bytes);
-            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Length * Ethash.HashBytes), "cache size returned");
+            IEthashDataSet<byte[]> cache = new EthashBytesCache(cacheSize, test.Seed.Bytes);
+            Assert.AreEqual((ulong)test.CacheSize, (ulong)(cache.Size), "cache size returned");
 
             // below we confirm that headerAndNonceHashed is calculated correctly
             // & that the method for calculating the result from mix hash is correct
@@ -94,7 +94,7 @@ namespace Ethereum.PoW.Test
             Assert.AreEqual(resultHalfTest, test.Result.Bytes, "half test");
 
             // here we confirm that the whole mix hash calculation is fine
-            (byte[] mixHash, byte[] result) = ethash.HashimotoLight((ulong)test.FullSize, cache, blockHeader, test.Nonce);
+            (byte[] mixHash, byte[] result) = ethash.Hashimoto((ulong)test.FullSize, cache, blockHeader, test.Nonce);
             Assert.AreEqual(test.MixHash.Bytes, mixHash, "mix hash");
             Assert.AreEqual(test.Result.Bytes, result, "result");
 
@@ -102,7 +102,7 @@ namespace Ethereum.PoW.Test
             // Assert.True(ethash.Validate(blockHeader), "validation");
             // seems it is just testing the nonce and mix hash but not difficulty
 
-            ulong dataSetSize = ethash.GetDataSize(blockHeader.Number);
+            ulong dataSetSize = Ethash.GetDataSize(blockHeader.Number);
             Assert.AreEqual((ulong)test.FullSize, dataSetSize, "data size requested");
         }
 
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
index 3d6afdb4c..5ac13a184 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak.cs
@@ -29,7 +29,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 32;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak256 _hash;
 
         public Keccak(Hex hex)
         {
@@ -105,7 +105,7 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        private static HashLib.Crypto.SHA3.Keccak256 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak256();
         }
diff --git a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
index 47aaa4ea8..8392cb3e5 100644
--- a/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
+++ b/src/Nethermind/Nethermind.Core/Crypto/Keccak512.cs
@@ -28,7 +28,7 @@ namespace Nethermind.Core.Crypto
     {
         private const int Size = 64;
 
-        [ThreadStatic] private static IHash _hash;
+        [ThreadStatic] private static HashLib.Crypto.SHA3.Keccak512 _hash;
 
         public Keccak512(Hex hex)
         {
@@ -89,7 +89,27 @@ namespace Nethermind.Core.Crypto
             return InternalCompute(input);
         }
 
-        private static IHash Init()
+        public static uint[] ComputeToUInts(byte[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeBytesToUint(input);
+        }
+
+        public static uint[] ComputeUIntsToUInts(uint[] input)
+        {
+            if (input == null || input.Length == 0)
+            {
+                throw new NotSupportedException();
+            }
+
+            return _hash.ComputeUIntsToUint(input);
+        }
+
+        private static HashLib.Crypto.SHA3.Keccak512 Init()
         {
             return HashFactory.Crypto.SHA3.CreateKeccak512();
         }
diff --git a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
index 853478906..3cafed103 100644
--- a/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
+++ b/src/Nethermind/Nethermind.HashLib/Crypto/SHA3/Keccak.cs
@@ -12,7 +12,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak256 : Keccak
+    public class Keccak256 : Keccak
     {
         public Keccak256()
             : base(HashLib.HashSize.HashSize256)
@@ -28,7 +28,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
         }
     }
 
-    internal class Keccak512 : Keccak
+    public class Keccak512 : Keccak
     {
         public Keccak512()
             : base(HashLib.HashSize.HashSize512)
@@ -37,7 +37,7 @@ namespace Nethermind.HashLib.Crypto.SHA3
     }
 
     [DebuggerNonUserCode]
-    internal abstract class Keccak : BlockHash, ICryptoNotBuildIn
+    public abstract class Keccak : BlockHash, ICryptoNotBuildIn
     {
         private readonly ulong[] m_state = new ulong[25];
 
@@ -2696,6 +2696,18 @@ namespace Nethermind.HashLib.Crypto.SHA3
             return Converters.ConvertULongsToBytes(m_state).SubArray(0, HashSize);
         }
 
+        protected override uint[] GetResultUInts()
+        {
+            uint[] result = new uint[HashSize / 4];
+            for (int i = 0; i < result.Length / 2; i = i + 1)
+            {
+                result[i * 2] = (uint)m_state[i];
+                result[i * 2 + 1] = (uint)(m_state[i] >> 32);
+            }
+
+            return result;
+        }
+
         public override void Initialize()
         {
             Array.Clear(m_state, 0, 25);
diff --git a/src/Nethermind/Nethermind.HashLib/Hash.cs b/src/Nethermind/Nethermind.HashLib/Hash.cs
index 4c29c599b..1e2880513 100644
--- a/src/Nethermind/Nethermind.HashLib/Hash.cs
+++ b/src/Nethermind/Nethermind.HashLib/Hash.cs
@@ -8,7 +8,7 @@ using Nethermind.HashLib.Extensions;
 namespace Nethermind.HashLib
 {
     [DebuggerStepThrough]
-    internal abstract class Hash : IHash
+    public abstract class Hash : IHash
     {
         private readonly int m_block_size;
         private readonly int m_hash_size;
@@ -210,6 +210,24 @@ namespace Nethermind.HashLib
             return result;
         }
 
+        public virtual uint[] ComputeBytesToUint(byte[] a_data)
+        {
+            Initialize();
+            TransformBytes(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
+        public virtual uint[] ComputeUIntsToUint(uint[] a_data)
+        {
+            Initialize();
+            TransformUInts(a_data);
+            uint[] result = TransformFinalUInts();
+            Initialize();
+            return result;
+        }
+
         public void TransformObject(object a_data)
         {
             if (a_data is byte)
@@ -510,5 +528,10 @@ namespace Nethermind.HashLib
         public abstract void Initialize();
         public abstract void TransformBytes(byte[] a_data, int a_index, int a_length);
         public abstract HashResult TransformFinal();
+
+        public virtual uint[] TransformFinalUInts()
+        {
+            throw new NotSupportedException();
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
index 7aa019f35..cde855423 100644
--- a/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashBuffer.cs
@@ -4,7 +4,7 @@ using System.Diagnostics;
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal class HashBuffer 
+    public class HashBuffer 
     {
         private byte[] m_data;
         private int m_pos;
diff --git a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
index 0b20821b1..5a09c942b 100644
--- a/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashCryptoNotBuildIn.cs
@@ -1,14 +1,15 @@
-﻿using System.Diagnostics;
+﻿using System;
+using System.Diagnostics;
 
 namespace Nethermind.HashLib
 {
     [DebuggerNonUserCode]
-    internal abstract class BlockHash : Hash, IBlockHash
+    public abstract class BlockHash : Hash, IBlockHash
     {
         protected readonly HashBuffer m_buffer;
         protected ulong m_processed_bytes;
 
-        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1) 
+        protected BlockHash(int a_hash_size, int a_block_size, int a_buffer_size = -1)
             : base(a_hash_size, a_block_size)
         {
             if (a_buffer_size == -1)
@@ -62,6 +63,20 @@ namespace Nethermind.HashLib
             return new HashResult(result);
         }
 
+        public override uint[] TransformFinalUInts()
+        {
+            Finish();
+
+            Debug.Assert(m_buffer.IsEmpty);
+
+            uint[] result = GetResultUInts();
+
+            Debug.Assert(result.Length == HashSize / 4);
+
+            Initialize();
+            return result;
+        }
+
         protected void TransformBuffer()
         {
             Debug.Assert(m_buffer.IsFull);
@@ -72,5 +87,11 @@ namespace Nethermind.HashLib
         protected abstract void Finish();
         protected abstract void TransformBlock(byte[] a_data, int a_index);
         protected abstract byte[] GetResult();
+
+        protected virtual uint[] GetResultUInts()
+        {
+            throw new NotSupportedException();
+
+        }
     }
 }
diff --git a/src/Nethermind/Nethermind.HashLib/HashFactory.cs b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
index 4945b33b8..3f3216fa3 100644
--- a/src/Nethermind/Nethermind.HashLib/HashFactory.cs
+++ b/src/Nethermind/Nethermind.HashLib/HashFactory.cs
@@ -1,4 +1,5 @@
 ﻿using System;
+using Nethermind.HashLib.Crypto.SHA3;
 
 namespace Nethermind.HashLib
 {
@@ -521,7 +522,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak224();
                 }
 
-                public static IHash CreateKeccak256()
+                public static Keccak256 CreateKeccak256()
                 {
                     return new HashLib.Crypto.SHA3.Keccak256();
                 }
@@ -531,7 +532,7 @@ namespace Nethermind.HashLib
                     return new HashLib.Crypto.SHA3.Keccak384();
                 }
 
-                public static IHash CreateKeccak512()
+                public static Keccak512 CreateKeccak512()
                 {
                     return new HashLib.Crypto.SHA3.Keccak512();
                 }
diff --git a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
index f71bb3015..29a133b81 100644
--- a/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
+++ b/src/Nethermind/Nethermind.Mining.Test/EthashTests.cs
@@ -1,9 +1,9 @@
 ﻿using System;
-using System.Linq;
-using System.Numerics;
 using Nethermind.Core;
+using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
+using Nethermind.HashLib;
 using NUnit.Framework;
 
 namespace Nethermind.Mining.Test
@@ -11,7 +11,7 @@ namespace Nethermind.Mining.Test
     [TestFixture]
     public class EthashTests
     {
-        private readonly long[] _cacheSizes = new long[]
+        private readonly uint[] _cacheSizes = new uint[]
         {
             16776896, 16907456, 17039296, 17170112, 17301056, 17432512, 17563072,
             17693888, 17824192, 17955904, 18087488, 18218176, 18349504, 18481088,
@@ -793,10 +793,9 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_data_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _dataSizes.Length; i++)
             {
-                ulong size = ethash.GetDataSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetDataSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _dataSizes[i], i);
             }
         }
@@ -804,12 +803,53 @@ namespace Nethermind.Mining.Test
         [Test]
         public void Test_cache_size()
         {
-            Ethash ethash = new Ethash();
             for (int i = 0; i < _cacheSizes.Length; i++)
             {
-                ulong size = ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
+                ulong size = Ethash.GetCacheSize((ulong)i * Ethash.EpochLength);
                 Assert.AreEqual(size, _cacheSizes[i], i);
             }
         }
+
+        [Test]
+        public void Test_two_cache_creation_methods_give_same_results()
+        {
+            byte[] seed = new byte[32];
+            byte[] hash = Keccak512.Compute(seed).Bytes;
+            uint[] hashInts = Keccak512.ComputeToUInts(seed);
+
+            byte[] hashFromInts = new byte[64];
+            Buffer.BlockCopy(hashInts, 0, hashFromInts, 0, 64);
+            
+            Assert.AreEqual(hash, hashFromInts, "Keccak uints");
+
+            EthashBytesCache bytesCache = new EthashBytesCache(_cacheSizes[0], seed);
+            EthashIntCache intCache = new EthashIntCache(_cacheSizes[0], seed);
+
+            int itemsToCheck = 1000;
+            Assert.AreEqual(bytesCache.Size, intCache.Size, "cache size");
+            for (int i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.Data[i];
+                byte[] bytes = bytesCache.Data[i];
+                
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"cache at index {i}, {j}");
+                }
+            }
+
+//            uint fullSize = (uint)(_dataSizes[0] / Ethash.HashBytes);
+            for (uint i = 0; i < itemsToCheck; i++)
+            {
+                uint[] ints = intCache.CalcDataSetItem(i);
+                byte[] bytes = bytesCache.CalcDataSetItem(i);
+                for (uint j = 0; j < ints.Length; j++)
+                {
+                    uint value = Ethash.GetUInt(bytes, j);
+                    Assert.AreEqual(value, ints[j], $"full at index {i}, {j}");
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Ethash.cs b/src/Nethermind/Nethermind.Mining/Ethash.cs
index 25b9644a5..ba7e6ea93 100644
--- a/src/Nethermind/Nethermind.Mining/Ethash.cs
+++ b/src/Nethermind/Nethermind.Mining/Ethash.cs
@@ -1,31 +1,26 @@
 ﻿using System;
 using System.Collections.Concurrent;
-using System.Collections.Generic;
 using System.Diagnostics;
-using System.IO;
-using System.Linq;
 using System.Numerics;
+using System.Runtime.CompilerServices;
 using Nethermind.Core;
 using Nethermind.Core.Crypto;
 using Nethermind.Core.Encoding;
 using Nethermind.Core.Extensions;
 
+[assembly: InternalsVisibleTo("Nethermind.Mining.Test")]
+
 namespace Nethermind.Mining
 {
     public class Ethash : IEthash
     {
-        public Ethash()
-        {
-            
-        }
-        
-        private readonly ConcurrentDictionary<ulong, byte[][]> _cacheCache = new ConcurrentDictionary<ulong, byte[][]>();
+        private readonly ConcurrentDictionary<ulong, IEthashDataSet<byte[]>> _cacheCache = new ConcurrentDictionary<ulong, IEthashDataSet<byte[]>>();
 
         public const int WordBytes = 4; // bytes in word
-        public ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
-        public ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
-        public uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
-        public uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
+        public static ulong DatasetBytesInit = (ulong)BigInteger.Pow(2, 30); // bytes in dataset at genesis
+        public static ulong DatasetBytesGrowth = (ulong)BigInteger.Pow(2, 23); // dataset growth per epoch
+        public static uint CacheBytesInit = (uint)BigInteger.Pow(2, 24); // bytes in cache at genesis
+        public static uint CacheBytesGrowth = (uint)BigInteger.Pow(2, 17); // cache growth per epoch
         public const int CacheMultiplier = 1024; // Size of the DAG relative to the cache
         public const ulong EpochLength = 30000; // blocks per epoch
         public const uint MixBytes = 128; // width of mix
@@ -34,12 +29,12 @@ namespace Nethermind.Mining
         public const int CacheRounds = 3; // number of rounds in cache production
         public const int Accesses = 64; // number of accesses in hashimoto loop
 
-        public ulong GetEpoch(BigInteger blockNumber)
+        public static ulong GetEpoch(BigInteger blockNumber)
         {
             return (ulong)blockNumber / EpochLength;
         }
 
-        public ulong GetDataSize(BigInteger blockNumber)
+        public static ulong GetDataSize(BigInteger blockNumber)
         {
             ulong size = DatasetBytesInit + DatasetBytesGrowth * GetEpoch(blockNumber);
             size -= MixBytes;
@@ -51,7 +46,7 @@ namespace Nethermind.Mining
             return size;
         }
 
-        public uint GetCacheSize(BigInteger blockNumber)
+        public static uint GetCacheSize(BigInteger blockNumber)
         {
             uint size = CacheBytesInit + CacheBytesGrowth * (uint)GetEpoch(blockNumber);
             size -= HashBytes;
@@ -96,7 +91,7 @@ namespace Nethermind.Mining
             return true;
         }
 
-        public Keccak GetSeedHash(BigInteger blockNumber)
+        public static Keccak GetSeedHash(BigInteger blockNumber)
         {
             byte[] seed = new byte[32];
             for (int i = 0; i < blockNumber / EpochLength; i++)
@@ -123,11 +118,11 @@ namespace Nethermind.Mining
             throw new NotImplementedException();
         }
 
-        public ulong Mine(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty, Func<ulong, byte[][], BlockHeader, ulong, (byte[], byte[])> hashimoto)
+        public ulong Mine(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, BigInteger difficulty)
         {
             ulong nonce = GetRandomNonce();
             byte[] target = BigInteger.Divide(_2To256, difficulty).ToBigEndianByteArray();
-            (byte[] _, byte[] result) = hashimoto(fullSize, dataSet, header, nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, dataSet, header, nonce);
             while (IsGreaterThanTarget(result, target))
             {
                 unchecked
@@ -139,127 +134,60 @@ namespace Nethermind.Mining
             return nonce;
         }
 
-        public ulong MineFull(ulong fullSize, byte[][] dataSet, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, dataSet, header, difficulty, HashimotoFull);
-        }
-
-        public ulong MineLight(ulong fullSize, byte[][] cache, BlockHeader header, BigInteger difficulty)
-        {
-            return Mine(fullSize, cache, header, difficulty, HashimotoLight);
-        }
-
-        public byte[][] BuildDataSet(ulong setSize, byte[][] cache)
-        {
-            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
-            byte[][] dataSet = new byte[(uint)(setSize / HashBytes)][];
-            for (uint i = 0; i < dataSet.Length; i++)
-            {
-                if (i % 100000 == 0)
-                {
-                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
-                }
-
-                dataSet[i] = CalcDataSetItem(i, cache);
-            }
-
-            return dataSet;
-        }
+        internal const uint FnvPrime = 0x01000193;
 
-        // TODO: optimize, check, work in progress
-        private byte[] CalcDataSetItem(uint i, byte[][] cache)
+        internal static void Fnv(byte[] b1, byte[] b2)
         {
-            uint n = (uint)cache.Length;
-            uint r = HashBytes / WordBytes;
-
-            byte[] mix = (byte[])cache[i % n].Clone();
-            SetUInt(mix, 0, i ^ GetUInt(mix, 0));
-            mix = Keccak512.Compute(mix).Bytes;
-
-            for (uint j = 0; j < DatasetParents; j++)
-            {
-                ulong cacheIndex = Fnv(i ^ j, GetUInt(mix, j % r));
-                mix = Fnv(mix, cache[cacheIndex % n]); // TODO: check
-            }
-
-            return Keccak512.Compute(mix).Bytes;
-        }
+            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
+            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
 
-        // TODO: optimize, check, work in progress
-        public byte[][] MakeCache(uint cacheSize, byte[] seed)
-        {   
-            uint cachePageCount = cacheSize / HashBytes;
-            byte[][] cache = new byte[cachePageCount][];
-            cache[0] = Keccak512.Compute(seed).Bytes;
-            for (uint i = 1; i < cachePageCount; i++)
-            {
-                cache[i] = Keccak512.Compute(cache[i - 1]).Bytes;
-            }
+            uint[] b1Ints = new uint[b1.Length / 4];
+            uint[] b2Ints = new uint[b1.Length / 4];
+            Buffer.BlockCopy(b1, 0, b1Ints, 0, b1.Length);
+            Buffer.BlockCopy(b2, 0, b2Ints, 0, b2.Length);
 
-            // http://www.hashcash.org/papers/memohash.pdf
-            // RandMemoHash
-            for (int _ = 0; _ < CacheRounds; _++)
+            // TODO: check this thing (in place calc)
+            for (uint i = 0; i < b1Ints.Length; i++)
             {
-                for (int i = 0; i < cachePageCount; i++)
-                {
-                    uint v = GetUInt(cache[i], 0) % cachePageCount;
-                    if (!Bytes.UnsafeCompare(cache[v], cache[v]))
-                    {
-                        throw new Exception();
-                    }
-
-                    cache[i] = Keccak512.Compute(cache[(i - 1 + cachePageCount) % cachePageCount].Xor(cache[v])).Bytes;
-                }
+                b1Ints[i] = Fnv(b1Ints[i], b2Ints[i]);
             }
 
-            return cache;
+            Buffer.BlockCopy(b1Ints, 0, b1, 0, b1.Length);
         }
 
-        private const uint FnvPrime = 0x01000193;
-
-        // TODO: optimize, check, work in progress
-        private static byte[] Fnv(byte[] b1, byte[] b2)
+        internal static void Fnv(uint[] b1, uint[] b2)
         {
-            Debug.Assert(b1.Length == b2.Length, "FNV expecting same length arrays");
-            Debug.Assert(b1.Length % 4 == 0, "FNV expecting length to be a multiple of 4");
-
-            // TODO: check this thing (in place calc)
-            byte[] result = new byte[b1.Length];
-            for (uint i = 0; i < b1.Length / 4; i++)
+            for (uint i = 0; i < b1.Length; i++)
             {
-                uint v1 = GetUInt(b1, i);
-                uint v2 = GetUInt(b2, i);
-                SetUInt(result, i, Fnv(v1, v2));
+                b1[i] = Fnv(b1[i], b2[i]);
             }
-
-            return result;
         }
 
-        private static void SetUInt(byte[] bytes, uint offset, uint value)
+        internal static uint Fnv(uint v1, uint v2)
         {
-            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
-            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+            return (v1 * FnvPrime) ^ v2;
         }
 
-        private static uint GetUInt(byte[] bytes, uint offset)
-        {
-            return bytes.Slice((int)offset * 4, 4).ToUInt32(Bytes.Endianness.Little);
-        }
+//        internal static void SetUInt(byte[] bytes, uint offset, uint value)
+//        {
+//            byte[] valueBytes = value.ToByteArray(Bytes.Endianness.Little);
+//            Buffer.BlockCopy(valueBytes, 0, bytes, (int)offset * 4, 4);
+//        }
 
-        private static uint Fnv(uint v1, uint v2)
+        internal static uint GetUInt(byte[] bytes, uint offset)
         {
-            return (v1 * FnvPrime) ^ v2;
+            return BitConverter.ToUInt32(BitConverter.IsLittleEndian ? bytes : Bytes.Reverse(bytes), (int)offset * 4);
         }
 
         private const int CacheCacheSizeLimit = 6;
-        
+
         public bool Validate(BlockHeader header)
-        {   
+        {
             ulong epoch = GetEpoch(header.Number);
-            
+
             ulong? epochToRemove = null;
-            byte[][] cache = _cacheCache.GetOrAdd(epoch, e =>
-            {   
+            IEthashDataSet<byte[]> cache = _cacheCache.GetOrAdd(epoch, e =>
+            {
                 uint cacheSize = GetCacheSize(header.Number);
                 Keccak seed = GetSeedHash(header.Number);
 
@@ -273,83 +201,74 @@ namespace Nethermind.Mining
                         {
                             if (index == indextToRemove)
                             {
-                                epochToRemove = epochInCache;                                
+                                epochToRemove = epochInCache;
                             }
                         }
                     }
                 }
-                
+
                 Console.WriteLine($"Building cache for epoch {epoch}");
-                return MakeCache(cacheSize, seed.Bytes); // TODO: load cache
+                return new EthashBytesCache(cacheSize, seed.Bytes);
             });
 
             if (epochToRemove.HasValue)
             {
                 Console.WriteLine($"Removing cache for epoch {epochToRemove}");
-                _cacheCache.TryRemove(epochToRemove.Value, out byte[][] removedItem);
+                _cacheCache.TryRemove(epochToRemove.Value, out IEthashDataSet<byte[]> removedItem);
             }
 
             ulong fullSize = GetDataSize(header.Number);
-            (byte[] _, byte[] result) = HashimotoLight(fullSize, cache, header, header.Nonce);
+            (byte[] _, byte[] result) = Hashimoto(fullSize, cache, header, header.Nonce);
 
             BigInteger threshold = BigInteger.Divide(BigInteger.Pow(2, 256), header.Difficulty);
-//            BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             BigInteger resultAsInteger = result.ToUnsignedBigInteger();
             return resultAsInteger < threshold;
         }
 
-        private (byte[], byte[]) Hashimoto(ulong fullSize, BlockHeader header, ulong nonce, Func<uint, byte[]> getDataSetItem)
+        public (byte[], byte[]) Hashimoto(ulong fullSize, IEthashDataSet<byte[]> dataSet, BlockHeader header, ulong nonce)
         {
             uint hashesInFull = (uint)(fullSize / HashBytes);
             uint wordsInMix = MixBytes / WordBytes;
             uint hashesInMix = MixBytes / HashBytes;
             byte[] headerHashed = Keccak.Compute(Rlp.Encode(header, false)).Bytes; // sic! Keccak here not Keccak512  // this tests fine
             byte[] headerAndNonceHashed = Keccak512.Compute(Bytes.Concat(headerHashed, nonce.ToByteArray(Bytes.Endianness.Little))).Bytes; // this tests fine
-            byte[] mix = new byte[MixBytes];
+            uint[] mixInts = new uint[MixBytes / WordBytes];
+
             for (int i = 0; i < hashesInMix; i++)
             {
-                Buffer.BlockCopy(headerAndNonceHashed, 0, mix, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
+                Buffer.BlockCopy(headerAndNonceHashed, 0, mixInts, i * headerAndNonceHashed.Length, headerAndNonceHashed.Length);
             }
 
             for (uint i = 0; i < Accesses; i++)
             {
-                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), GetUInt(mix, i % wordsInMix)) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
-                byte[] newData = new byte[MixBytes];
+                uint p = Fnv(i ^ GetUInt(headerAndNonceHashed, 0), mixInts[i % wordsInMix]) % (hashesInFull / hashesInMix) * hashesInMix; // since we take 'hashesInMix' consecutive blocks we want only starting indices of such blocks
+                uint[] newData = new uint[MixBytes / WordBytes];
                 for (uint j = 0; j < hashesInMix; j++)
                 {
-                    byte[] item = getDataSetItem(p + j);
+                    byte[] item = dataSet.CalcDataSetItem(p + j);
                     Buffer.BlockCopy(item, 0, newData, (int)(j * item.Length), item.Length);
                 }
 
-//                mix = Fnv(mix, newData);
-                mix = Fnv(mix, newData);
+                Fnv(mixInts, newData);
             }
-
-
-            byte[] cmix = new byte[MixBytes / 4];
-            for (uint i = 0; i < MixBytes / 4; i += 4)
+            
+            byte[] cmix = new byte[MixBytes / WordBytes];
+            uint[] cmixInts = new uint[MixBytes / WordBytes / 4];
+            
+            for (uint i = 0; i < mixInts.Length; i += 4)
             {
-                uint fnv = Fnv(Fnv(Fnv(GetUInt(mix, i), GetUInt(mix, i + 1)), GetUInt(mix, i + 2)), GetUInt(mix, i + 3));
-                SetUInt(cmix, i / 4, fnv);
+                cmixInts[i / 4] = Fnv(Fnv(Fnv(mixInts[i], mixInts[i+1]), mixInts[i + 2]), mixInts[i + 3]);
             }
+            
+            Buffer.BlockCopy(cmixInts, 0, cmix, 0, cmix.Length);
 
             if (header.MixHash != Keccak.Zero && !Bytes.UnsafeCompare(cmix, header.MixHash.Bytes))
             {
                 // TODO: handle properly
                 throw new InvalidOperationException();
             }
-            
-            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
-        }
-
-        public (byte[], byte[]) HashimotoLight(ulong fullSize, byte[][] cache, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => CalcDataSetItem(index, cache));
-        }
 
-        public (byte[], byte[]) HashimotoFull(ulong fullSize, byte[][] dataSet, BlockHeader header, ulong nonce)
-        {
-            return Hashimoto(fullSize, header, nonce, index => dataSet[index]);
+            return (cmix, Keccak.Compute(Bytes.Concat(headerAndNonceHashed, cmix)).Bytes); // this tests fine
         }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
new file mode 100644
index 000000000..6f2dbdd4a
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashBytesCache.cs
@@ -0,0 +1,61 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashBytesCache : IEthashDataSet<byte[]>
+    {
+        internal byte[][] Data { get; set; }
+
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public EthashBytesCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new byte[cachePageCount][];
+            Data[0] = Keccak512.Compute(seed).Bytes;
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.Compute(Data[i - 1]).Bytes;
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Ethash.GetUInt(Data[i], 0) % cachePageCount;
+                    Data[i] = Keccak512.Compute(Data[(i - 1 + cachePageCount) % cachePageCount].Xor(Data[v])).Bytes;
+                }
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+
+            uint[] mixInts = new uint[Ethash.HashBytes / Ethash.WordBytes];
+            Buffer.BlockCopy(Data[i % n], 0, mixInts, 0, (int)Ethash.HashBytes);
+
+            mixInts[0] = i ^ mixInts[0];
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+
+            uint[] dataInts = new uint[mixInts.Length];
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                ulong cacheIndex = Ethash.Fnv(i ^ j, mixInts[j % r]);
+                Buffer.BlockCopy(Data[cacheIndex % n], 0, dataInts, 0, (int)Ethash.HashBytes);
+                Ethash.Fnv(mixInts, dataInts);
+            }
+
+            mixInts = Keccak512.ComputeUIntsToUInts(mixInts);
+            
+            byte[] mix = new byte[Ethash.HashBytes];
+            Buffer.BlockCopy(mixInts, 0, mix, 0, (int)Ethash.HashBytes);
+            return mix;
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/EthashIntCache.cs b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
new file mode 100644
index 000000000..c29115cf9
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/EthashIntCache.cs
@@ -0,0 +1,57 @@
+﻿using System;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Mining
+{
+    public class EthashIntCache : IEthashDataSet<uint[]>
+    {
+        internal uint[][] Data { get; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+        
+        public EthashIntCache(uint cacheSize, byte[] seed)
+        {
+            uint cachePageCount = cacheSize / Ethash.HashBytes;
+            Data = new uint[cachePageCount][];
+            Data[0] = Keccak512.ComputeToUInts(seed);
+            for (uint i = 1; i < cachePageCount; i++)
+            {
+                Data[i] = Keccak512.ComputeUIntsToUInts(Data[i - 1]);
+            }
+
+            // http://www.hashcash.org/papers/memohash.pdf
+            // RandMemoHash
+            for (int _ = 0; _ < Ethash.CacheRounds; _++)
+            {
+                for (int i = 0; i < cachePageCount; i++)
+                {
+                    uint v = Data[i][0] % cachePageCount;
+                    byte[] left = new byte[Ethash.HashBytes];
+                    byte[] right = new byte[Ethash.HashBytes];
+                    Buffer.BlockCopy(Data[(i - 1 + cachePageCount) % cachePageCount], 0, left, 0, (int)Ethash.HashBytes);
+                    Buffer.BlockCopy(Data[v], 0, right, 0, (int)Ethash.HashBytes);
+                    Data[i] = Keccak512.ComputeToUInts(left.Xor(right));
+                }
+            }
+        }
+
+        public uint[] CalcDataSetItem(uint i)
+        {
+            uint n = (uint)Data.Length;
+            uint r = Ethash.HashBytes / Ethash.WordBytes;
+            
+            uint[] mix = (uint[])Data[i % n].Clone();
+            mix[0] = i ^ mix[0];
+            mix = Keccak512.ComputeUIntsToUInts(mix);
+
+            for (uint j = 0; j < Ethash.DatasetParents; j++)
+            {
+                uint cacheIndex = Ethash.Fnv(i ^ j, mix[j % r]);
+                Ethash.Fnv(mix, Data[cacheIndex % n]);
+            }
+
+            return Keccak512.ComputeUIntsToUInts(mix);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/FullDataSet.cs b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
new file mode 100644
index 000000000..66a25dfbf
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/FullDataSet.cs
@@ -0,0 +1,31 @@
+﻿using System;
+
+namespace Nethermind.Mining
+{
+    public class FullDataSet : IEthashDataSet<byte[]>
+    {
+        public byte[][] Data { get; set; }
+        
+        public uint Size => (uint)(Data.Length * Ethash.HashBytes);
+
+        public FullDataSet(ulong setSize, IEthashDataSet<byte[]> cache)
+        {
+            Console.WriteLine($"building data set of length {setSize}"); // TODO: temp, remove
+            Data = new byte[(uint)(setSize / Ethash.HashBytes)][];
+            for (uint i = 0; i < Data.Length; i++)
+            {
+                if (i % 100000 == 0)
+                {
+                    Console.WriteLine($"building data set of length {setSize}, built {i}"); // TODO: temp, remove
+                }
+
+                Data[i] = cache.CalcDataSetItem(i);
+            }
+        }
+
+        public byte[] CalcDataSetItem(uint i)
+        {
+            return Data[i];
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
new file mode 100644
index 000000000..87974e413
--- /dev/null
+++ b/src/Nethermind/Nethermind.Mining/IEthashDataSet.cs
@@ -0,0 +1,8 @@
+﻿namespace Nethermind.Mining
+{
+    public interface IEthashDataSet<out T>
+    {
+        uint Size { get; }
+        T CalcDataSetItem(uint i);
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
index 56c6bd1ee..07b40d0d4 100644
--- a/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
+++ b/src/Nethermind/Nethermind.Mining/Nethermind.Mining.csproj
@@ -8,6 +8,9 @@
   <ItemGroup>
     <DotNetCliToolReference Include="dotnet-xunit" Version="2.3.1" />
   </ItemGroup>
+  <ItemGroup>
+    <PackageReference Include="System.Memory" Version="4.5.0-preview1-26216-02" />
+  </ItemGroup>
   <ItemGroup>
     <ProjectReference Include="..\Nethermind.Core\Nethermind.Core.csproj">
       <Project>{5751C57B-9F2D-45DE-BCC2-42645B85E39E}</Project>
