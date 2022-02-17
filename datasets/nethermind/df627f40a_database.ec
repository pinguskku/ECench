commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
commit df627f40af93ab1a453c7aa9d78166c5617a84b1
Author: Tomasz Kajetan Stanczak <tkstanczak@users.noreply.github.com>
Date:   Sat Aug 17 14:01:06 2019 +0100

    move the TrieNodeDecoder inside TrieNode so we do not have to expose private members, also added test coverage and fixed the tiny extension bug, also added a few performance improvements

diff --git a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
index ba2baabbe..e392e8bf4 100644
--- a/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
+++ b/src/Nethermind/Nethermind.Blockchain.Test/Synchronization/FastSync/NodeDataDownloaderTests.cs
@@ -36,7 +36,7 @@ using NUnit.Framework;
 
 namespace Nethermind.Blockchain.Test.Synchronization.FastSync
 {
-    [TestFixture, Explicit("Travis just cannot run it")]
+    [TestFixture]
     public class NodeDataDownloaderTests
     {
         private static readonly byte[] Code0 = {0, 0};
diff --git a/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
new file mode 100644
index 000000000..5d8bfda52
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store.Test/TrieNodeTests.cs
@@ -0,0 +1,172 @@
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
+using System.Linq;
+using Nethermind.Core.Crypto;
+using Nethermind.Core.Encoding;
+using NUnit.Framework;
+
+namespace Nethermind.Store.Test
+{
+    [TestFixture]
+    public class TrieNodeTests
+    {
+        private TrieNode _tiniestLeaf;
+        private TrieNode _heavyLeaf;
+
+        public TrieNodeTests()
+        {
+            _tiniestLeaf = new TrieNode(NodeType.Leaf);
+            _tiniestLeaf.Key = new HexPrefix(true, 5);
+            _tiniestLeaf.Value = new byte[] {10};
+            
+            _heavyLeaf = new TrieNode(NodeType.Leaf);
+            _heavyLeaf.Key = new HexPrefix(true, 5);
+            _heavyLeaf.Value = Keccak.EmptyTreeHash.Bytes.Concat(Keccak.EmptyTreeHash.Bytes).ToArray();
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode.SetChild(11, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(11);
+
+            Assert.AreEqual(decoded.GetChildHash(11), decodedTiniest.Keccak, "value");
+        }
+        
+        [Test]
+        public void Can_encode_decode_tiny_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _tiniestLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+            decodedTiniest.ResolveNode(null);
+
+            Assert.AreEqual(_tiniestLeaf.Value, decodedTiniest.Value, "value");
+            Assert.AreEqual(_tiniestLeaf.Key.ToBytes(), decodedTiniest.Key.ToBytes(), "key");
+        }
+        
+        [Test]
+        public void Can_encode_decode_heavy_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode.Key = new HexPrefix(false, 5);
+            trieNode.SetChild(0, _heavyLeaf);
+
+            Rlp rlp = trieNode.RlpEncode();
+
+            TrieNode decoded = new TrieNode(NodeType.Unknown, rlp);
+            decoded.ResolveNode(null);
+            TrieNode decodedTiniest = decoded.GetChild(0);
+
+            Assert.AreEqual(decoded.GetChildHash(0), decodedTiniest.Keccak, "keccak");
+        }
+
+        [Test]
+        public void Can_set_and_get_children_using_indexer()
+        {
+            TrieNode tiniest = new TrieNode(NodeType.Leaf);
+            tiniest.Key = new HexPrefix(true, 5);
+            tiniest.Value = new byte[] {10};
+
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = tiniest;
+            TrieNode getResult = trieNode[11];
+            Assert.AreSame(tiniest, getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _heavyLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_a_branch()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Branch);
+            trieNode[11] = _tiniestLeaf;
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Branch, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(11);
+            Assert.Null(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_hashed_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _heavyLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.NotNull(getResult);
+        }
+        
+        [Test]
+        public void Get_child_hash_works_on_inlined_child_of_an_extension()
+        {
+            TrieNode trieNode = new TrieNode(NodeType.Extension);
+            trieNode[0] = _tiniestLeaf;
+            trieNode.Key = new HexPrefix(false, 5);
+            Rlp rlp = trieNode.RlpEncode();
+            TrieNode decoded = new TrieNode(NodeType.Extension, rlp);
+            
+            Keccak getResult = decoded.GetChildHash(0);
+            Assert.Null(getResult);
+        }
+    }
+}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
deleted file mode 100644
index 2d3e6cc39..000000000
--- a/src/Nethermind/Nethermind.Store/TreeNodeDecoder.cs
+++ /dev/null
@@ -1,181 +0,0 @@
-/*
- * Copyright (c) 2018 Demerzel Solutions Limited
- * This file is part of the Nethermind library.
- *
- * The Nethermind library is free software: you can redistribute it and/or modify
- * it under the terms of the GNU Lesser General Public License as published by
- * the Free Software Foundation, either version 3 of the License, or
- * (at your option) any later version.
- *
- * The Nethermind library is distributed in the hope that it will be useful,
- * but WITHOUT ANY WARRANTY; without even the implied warranty of
- * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
- * GNU Lesser General Public License for more details.
- *
- * You should have received a copy of the GNU Lesser General Public License
- * along with the Nethermind. If not, see <http://www.gnu.org/licenses/>.
- */
-
-using System;
-using Nethermind.Core.Encoding;
-using Nethermind.Core.Extensions;
-
-namespace Nethermind.Store
-{
-    public class TreeNodeDecoder
-    {
-        private Rlp RlpEncodeBranch(TrieNode item)
-        {
-            int valueRlpLength = Rlp.LengthOf(item.Value);
-            int contentLength = valueRlpLength + GetChildrenRlpLength(item);
-            int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
-            byte[] result = new byte[sequenceLength];
-            Span<byte> resultSpan = result.AsSpan();
-            int position = Rlp.StartSequence(result, 0, contentLength);
-            WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
-            position = sequenceLength - valueRlpLength;
-            Rlp.Encode(result, position, item.Value);
-            return new Rlp(result);
-        }
-
-        public Rlp Encode(TrieNode item)
-        {
-            Metrics.TreeNodeRlpEncodings++;
-            if (item == null)
-            {
-                return Rlp.OfEmptySequence;
-            }
-            
-            if (item.IsLeaf)
-            {
-                return EncodeLeaf(item);
-            }
-
-            if (item.IsBranch)
-            {
-                return RlpEncodeBranch(item);
-            }
-
-            if (item.IsExtension)
-            {
-                return EncodeExtension(item);
-            }
-
-            throw new InvalidOperationException($"Unknown node type {item.NodeType}");
-        }
-
-        private static Rlp EncodeExtension(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            TrieNode nodeRef = item.GetChild(0);
-            nodeRef.ResolveKey(false);
-            int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            if (nodeRef.Keccak == null)
-            {
-                // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
-                // so |
-                // so |
-                // so E - - - - - - - - - - - - - - - 
-                // so |
-                // so |
-                rlpStream.Encode(nodeRef.FullRlp);
-            }
-            else
-            {
-                rlpStream.Encode(nodeRef.Keccak);
-            }
-
-            return new Rlp(rlpStream.Data);
-        }
-
-        private static Rlp EncodeLeaf(TrieNode item)
-        {
-            byte[] keyBytes = item.Key.ToBytes();
-            int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
-            int totalLength = Rlp.LengthOfSequence(contentLength);
-            RlpStream rlpStream = new RlpStream(totalLength);
-            rlpStream.StartSequence(contentLength);
-            rlpStream.Encode(keyBytes);
-            rlpStream.Encode(item.Value);
-            return new Rlp(rlpStream.Data);
-        }
-
-        private int GetChildrenRlpLength(TrieNode item)
-        {
-            int totalLength = 0;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (item.DecoderContext != null && item._data[i] == null)
-                {
-                    (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
-                    totalLength += prefixLength + contentLength;
-                }
-                else
-                {
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        totalLength++;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
-                    }
-                }
-                
-                item.DecoderContext?.SkipItem();
-            }
-
-            return totalLength;
-        }
-
-        private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
-        {
-            int position = 0;
-            var context = item.DecoderContext;
-            item.InitData();
-            item.PositionContextOnItem(0);
-            for (int i = 0; i < 16; i++)
-            {
-                if (context != null && item._data[i] == null)
-                {
-                    int length = context.PeekNextRlpLength();
-                    Span<byte> nextItem = context.Data.Slice(context.Position, length);
-                    nextItem.CopyTo(destination.Slice(position, nextItem.Length));
-                    position += nextItem.Length;
-                    context.SkipItem();
-                }
-                else
-                {
-                    context?.SkipItem();
-                    if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
-                    {
-                        destination[position++] = 128;
-                    }
-                    else
-                    {
-                        TrieNode childNode = (TrieNode) item._data[i];
-                        childNode.ResolveKey(false);
-                        if (childNode.Keccak == null)
-                        {
-                            Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
-                            fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
-                            position += fullRlp.Length;
-                        }
-                        else
-                        {
-                            position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
-                        }
-                    }
-                }
-            }
-        }
-    }
-}
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNode.cs b/src/Nethermind/Nethermind.Store/TrieNode.cs
index e68918a5a..1f274ac16 100644
--- a/src/Nethermind/Nethermind.Store/TrieNode.cs
+++ b/src/Nethermind/Nethermind.Store/TrieNode.cs
@@ -30,12 +30,12 @@ namespace Nethermind.Store
 {
     public class TrieNode
     {
-        private static TreeNodeDecoder _nodeDecoder = new TreeNodeDecoder();
+        private static TrieNodeDecoder _nodeDecoder = new TrieNodeDecoder();
         private static AccountDecoder _accountDecoder = new AccountDecoder();
 
-        public static object NullNode = new object();
+        private static object NullNode = new object();
 
-        internal object[] _data;
+        private object[] _data;
         private bool _isDirty;
 
         public TrieNode(NodeType nodeType)
@@ -67,6 +67,11 @@ namespace Nethermind.Store
                     {
                         nonEmptyNodes++;
                     }
+
+                    if (nonEmptyNodes > 2)
+                    {
+                        return true;
+                    }
                 }
 
                 if (AllowBranchValues)
@@ -93,7 +98,7 @@ namespace Nethermind.Store
         }
 
         public Keccak Keccak { get; set; }
-        internal Rlp.DecoderContext DecoderContext { get; set; }
+        private Rlp.DecoderContext DecoderContext { get; set; }
         public Rlp FullRlp { get; private set; }
         public NodeType NodeType { get; set; }
 
@@ -139,7 +144,7 @@ namespace Nethermind.Store
                     }
                     else
                     {
-                        PositionContextOnItem(16);
+                        SeekChild(16);
                         _data[16] = DecoderContext.DecodeByteArray();
                     }
                 }
@@ -243,20 +248,17 @@ namespace Nethermind.Store
                 return;
             }
 
-            if (FullRlp == null || IsDirty) // TODO: review
+            if (FullRlp == null || IsDirty)
             {
                 FullRlp = RlpEncode();
                 DecoderContext = FullRlp.Bytes.AsRlpContext();
             }
 
-            if (FullRlp.Length < 32)
+            /* nodes that are descendants of other nodes are stored inline
+             * if their serialized length is less than Keccak length
+             * */
+            if (FullRlp.Length < 32 && !isRoot)
             {
-                if (isRoot)
-                {
-                    Metrics.TreeNodeHashCalculations++;
-                    Keccak = Keccak.Compute(FullRlp);
-                }
-
                 return;
             }
 
@@ -270,7 +272,7 @@ namespace Nethermind.Store
             return _nodeDecoder.Encode(this);
         }
 
-        internal void InitData()
+        private void InitData()
         {
             if (_data == null)
             {
@@ -288,15 +290,20 @@ namespace Nethermind.Store
             }
         }
 
-        internal void PositionContextOnItem(int itemToSetOn)
+        private void SeekChild(int itemToSetOn)
         {
             if (DecoderContext == null)
             {
                 return;
             }
-            
+
             DecoderContext.Reset();
             DecoderContext.SkipLength();
+            if (IsExtension)
+            {
+                DecoderContext.SkipItem();
+            }
+            
             for (int i = 0; i < itemToSetOn; i++)
             {
                 DecoderContext.SkipItem();
@@ -306,15 +313,15 @@ namespace Nethermind.Store
         private void ResolveChild(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (context == null)
             {
                 return;
             }
 
+            InitData();
             if (_data[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 int prefix = context.ReadByte();
                 if (prefix == 0)
                 {
@@ -347,17 +354,7 @@ namespace Nethermind.Store
                 return null;
             }
 
-            if (NodeType == NodeType.Extension)
-            {
-                context.Reset();
-                context.ReadSequenceLength();
-                context.DecodeByteArraySpan();
-
-                // TODO: looks like this never supports short extensions? (try the example with the minimal branch)
-                return context.DecodeKeccak();
-            }
-
-            PositionContextOnItem(i);
+            SeekChild(i);
             (int _, int length) = context.PeekPrefixAndContentLength();
             return length == 32 ? context.DecodeKeccak() : null;
         }
@@ -365,19 +362,18 @@ namespace Nethermind.Store
         public bool IsChildNull(int i)
         {
             Rlp.DecoderContext context = DecoderContext;
-            InitData();
             if (!IsBranch)
             {
                 throw new InvalidOperationException("only on branch");
             }
 
-            if (context != null && _data[i] == null)
+            if (context != null && _data?[i] == null)
             {
-                PositionContextOnItem(i);
+                SeekChild(i);
                 return context.PeekNextRlpLength() == 1;
             }
 
-            return ReferenceEquals(_data[i], NullNode) || _data[i] == null;
+            return ReferenceEquals(_data[i], NullNode) || _data?[i] == null;
         }
 
         public bool IsChildDirty(int i)
@@ -395,11 +391,14 @@ namespace Nethermind.Store
             return ((TrieNode) _data[i]).IsDirty;
         }
 
-        public TrieNode GetChild(int i)
+        public TrieNode GetChild(int childIndex)
         {
-            int index = IsExtension ? i + 1 : i;
-            ResolveChild(i);
-            return ReferenceEquals(_data[index], NullNode) ? null : (TrieNode) _data[index];
+            /* extensions store value before the child while branches store children before the value
+             * so just to treat them in the same way we update index on extensions
+             */
+            childIndex = IsExtension ? childIndex + 1 : childIndex;
+            ResolveChild(childIndex);
+            return ReferenceEquals(_data[childIndex], NullNode) ? null : (TrieNode) _data[childIndex];
         }
 
         public void SetChild(int i, TrieNode node)
@@ -492,5 +491,162 @@ namespace Nethermind.Store
                     throw new ArgumentOutOfRangeException();
             }
         }
+
+        private class TrieNodeDecoder
+        {
+            private Rlp RlpEncodeBranch(TrieNode item)
+            {
+                int valueRlpLength = Rlp.LengthOf(item.Value);
+                int contentLength = valueRlpLength + GetChildrenRlpLength(item);
+                int sequenceLength = Rlp.GetSequenceRlpLength(contentLength);
+                byte[] result = new byte[sequenceLength];
+                Span<byte> resultSpan = result.AsSpan();
+                int position = Rlp.StartSequence(result, 0, contentLength);
+                WriteChildrenRlp(item, resultSpan.Slice(position, contentLength - valueRlpLength));
+                position = sequenceLength - valueRlpLength;
+                Rlp.Encode(result, position, item.Value);
+                return new Rlp(result);
+            }
+
+            public Rlp Encode(TrieNode item)
+            {
+                Metrics.TreeNodeRlpEncodings++;
+                if (item == null)
+                {
+                    return Rlp.OfEmptySequence;
+                }
+
+                if (item.IsLeaf)
+                {
+                    return EncodeLeaf(item);
+                }
+
+                if (item.IsBranch)
+                {
+                    return RlpEncodeBranch(item);
+                }
+
+                if (item.IsExtension)
+                {
+                    return EncodeExtension(item);
+                }
+
+                throw new InvalidOperationException($"Unknown node type {item.NodeType}");
+            }
+
+            private static Rlp EncodeExtension(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                TrieNode nodeRef = item.GetChild(0);
+                nodeRef.ResolveKey(false);
+                int contentLength = Rlp.LengthOf(keyBytes) + (nodeRef.Keccak == null ? nodeRef.FullRlp.Length : Rlp.LengthOfKeccakRlp);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                if (nodeRef.Keccak == null)
+                {
+                    // I think it can only happen if we have a short extension to a branch with a short extension as the only child?
+                    // so |
+                    // so |
+                    // so E - - - - - - - - - - - - - - - 
+                    // so |
+                    // so |
+                    rlpStream.Encode(nodeRef.FullRlp);
+                }
+                else
+                {
+                    rlpStream.Encode(nodeRef.Keccak);
+                }
+
+                return new Rlp(rlpStream.Data);
+            }
+
+            private static Rlp EncodeLeaf(TrieNode item)
+            {
+                byte[] keyBytes = item.Key.ToBytes();
+                int contentLength = Rlp.LengthOf(keyBytes) + Rlp.LengthOf(item.Value);
+                int totalLength = Rlp.LengthOfSequence(contentLength);
+                RlpStream rlpStream = new RlpStream(totalLength);
+                rlpStream.StartSequence(contentLength);
+                rlpStream.Encode(keyBytes);
+                rlpStream.Encode(item.Value);
+                return new Rlp(rlpStream.Data);
+            }
+
+            private int GetChildrenRlpLength(TrieNode item)
+            {
+                int totalLength = 0;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (item.DecoderContext != null && item._data[i] == null)
+                    {
+                        (int prefixLength, int contentLength) = item.DecoderContext.PeekPrefixAndContentLength();
+                        totalLength += prefixLength + contentLength;
+                    }
+                    else
+                    {
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            totalLength++;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            totalLength += childNode.Keccak == null ? childNode.FullRlp.Length : Rlp.LengthOfKeccakRlp;
+                        }
+                    }
+
+                    item.DecoderContext?.SkipItem();
+                }
+
+                return totalLength;
+            }
+
+            private void WriteChildrenRlp(TrieNode item, Span<byte> destination)
+            {
+                int position = 0;
+                var context = item.DecoderContext;
+                item.InitData();
+                item.SeekChild(0);
+                for (int i = 0; i < 16; i++)
+                {
+                    if (context != null && item._data[i] == null)
+                    {
+                        int length = context.PeekNextRlpLength();
+                        Span<byte> nextItem = context.Data.AsSpan().Slice(context.Position, length);
+                        nextItem.CopyTo(destination.Slice(position, nextItem.Length));
+                        position += nextItem.Length;
+                        context.SkipItem();
+                    }
+                    else
+                    {
+                        context?.SkipItem();
+                        if (ReferenceEquals(item._data[i], TrieNode.NullNode) || item._data[i] == null)
+                        {
+                            destination[position++] = 128;
+                        }
+                        else
+                        {
+                            TrieNode childNode = (TrieNode) item._data[i];
+                            childNode.ResolveKey(false);
+                            if (childNode.Keccak == null)
+                            {
+                                Span<byte> fullRlp = childNode.FullRlp.Bytes.AsSpan();
+                                fullRlp.CopyTo(destination.Slice(position, fullRlp.Length));
+                                position += fullRlp.Length;
+                            }
+                            else
+                            {
+                                position = Rlp.Encode(destination, position, childNode.Keccak.Bytes);
+                            }
+                        }
+                    }
+                }
+            }
+        }
     }
 }
\ No newline at end of file
diff --git a/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
new file mode 100644
index 000000000..9ab12cb0b
--- /dev/null
+++ b/src/Nethermind/Nethermind.Store/TrieNodeDecoder.cs
@@ -0,0 +1,26 @@
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
+using System;
+using Nethermind.Core.Encoding;
+using Nethermind.Core.Extensions;
+
+namespace Nethermind.Store
+{
+   
+}
\ No newline at end of file
