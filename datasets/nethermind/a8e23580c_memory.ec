commit a8e23580cc8ebde7c624405c1e3a5b01b31235bd
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:02:35 2018 +0100

    removed unnecessary branch creation

diff --git a/src/Nethermind/Nethermind.Store/Branch.cs b/src/Nethermind/Nethermind.Store/Branch.cs
index 2735e71be..90561cf2b 100644
--- a/src/Nethermind/Nethermind.Store/Branch.cs
+++ b/src/Nethermind/Nethermind.Store/Branch.cs
@@ -51,6 +51,7 @@ namespace Nethermind.Store
         }
 
         public bool IsValid => (Value.Length > 0 ? 1 : 0) + Nodes.Count(n => n != null) > 1;
+        public bool IsValidWithOneNodeLess => (Value.Length > 0 ? 1 : 0) + Nodes.Count(n => n != null) - 1 > 1;
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Store/TreeOperation.cs b/src/Nethermind/Nethermind.Store/TreeOperation.cs
index f4cd3483d..54e9c09e4 100644
--- a/src/Nethermind/Nethermind.Store/TreeOperation.cs
+++ b/src/Nethermind/Nethermind.Store/TreeOperation.cs
@@ -142,35 +142,44 @@ namespace Nethermind.Store
 
                 if (node is Branch branch)
                 {
-                    Branch newBranch = new Branch();
-                    newBranch.IsDirty = true;
-                    for (int i = 0; i < 16; i++)
+//                    _tree.DeleteNode(branch.Nodes[parentOnStack.PathIndex], true);
+                    if (!(nextNodeRef == null && !branch.IsValidWithOneNodeLess))
                     {
-                        newBranch.Nodes[i] = branch.Nodes[i];
-                    }
+                        Branch newBranch = new Branch();
+                        newBranch.IsDirty = true;
+                        for (int i = 0; i < 16; i++)
+                        {
+                            newBranch.Nodes[i] = branch.Nodes[i];
+                        }
 
-                    newBranch.Value = branch.Value;
-                    newBranch.Nodes[parentOnStack.PathIndex] = nextNodeRef;
+                        newBranch.Value = branch.Value;
+                        newBranch.Nodes[parentOnStack.PathIndex] = nextNodeRef;
 
-//                    _tree.DeleteNode(branch.Nodes[parentOnStack.PathIndex], true);
-                    if (newBranch.IsValid)
-                    {
                         nextNodeRef = new NodeRef(newBranch, isRoot);
                         nextNode = newBranch;
                     }
                     else
                     {
-                        if (newBranch.Value.Length != 0)
+                        if (branch.Value.Length != 0)
                         {
-                            Leaf leafFromBranch = new Leaf(new HexPrefix(true), newBranch.Value);
+                            Leaf leafFromBranch = new Leaf(new HexPrefix(true), branch.Value);
                             leafFromBranch.IsDirty = true;
                             nextNodeRef = new NodeRef(leafFromBranch, isRoot);
                             nextNode = leafFromBranch;
                         }
                         else
                         {
-                            int childNodeIndex = Array.FindIndex(newBranch.Nodes, n => n != null);
-                            NodeRef childNodeRef = newBranch.Nodes[childNodeIndex];
+                            int childNodeIndex = 0;
+                            for (int i = 0; i < 16; i++)
+                            {
+                                if (i != parentOnStack.PathIndex && branch.Nodes[i] != null)
+                                {
+                                    childNodeIndex = i;
+                                    break;
+                                }
+                            }
+
+                            NodeRef childNodeRef = branch.Nodes[childNodeIndex];
                             if (childNodeRef == null)
                             {
                                 throw new InvalidOperationException("Before updating branch should have had at least two non-empty children");
@@ -270,8 +279,17 @@ namespace Nethermind.Store
 
                 if (_updateValue == null)
                 {
+                    if (node.Value == null)
+                    {
+                        return null;
+                    }
+
                     ConnectNodes(null);
                 }
+                else if (Bytes.UnsafeCompare(_updateValue, node.Value))
+                {
+                    return _updateValue;
+                }
                 else
                 {
                     Branch newBranch = new Branch(node.Nodes, _updateValue);
commit a8e23580cc8ebde7c624405c1e3a5b01b31235bd
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:02:35 2018 +0100

    removed unnecessary branch creation

diff --git a/src/Nethermind/Nethermind.Store/Branch.cs b/src/Nethermind/Nethermind.Store/Branch.cs
index 2735e71be..90561cf2b 100644
--- a/src/Nethermind/Nethermind.Store/Branch.cs
+++ b/src/Nethermind/Nethermind.Store/Branch.cs
@@ -51,6 +51,7 @@ namespace Nethermind.Store
         }
 
         public bool IsValid => (Value.Length > 0 ? 1 : 0) + Nodes.Count(n => n != null) > 1;
+        public bool IsValidWithOneNodeLess => (Value.Length > 0 ? 1 : 0) + Nodes.Count(n => n != null) - 1 > 1;
 
         public override string ToString()
         {
diff --git a/src/Nethermind/Nethermind.Store/TreeOperation.cs b/src/Nethermind/Nethermind.Store/TreeOperation.cs
index f4cd3483d..54e9c09e4 100644
--- a/src/Nethermind/Nethermind.Store/TreeOperation.cs
+++ b/src/Nethermind/Nethermind.Store/TreeOperation.cs
@@ -142,35 +142,44 @@ namespace Nethermind.Store
 
                 if (node is Branch branch)
                 {
-                    Branch newBranch = new Branch();
-                    newBranch.IsDirty = true;
-                    for (int i = 0; i < 16; i++)
+//                    _tree.DeleteNode(branch.Nodes[parentOnStack.PathIndex], true);
+                    if (!(nextNodeRef == null && !branch.IsValidWithOneNodeLess))
                     {
-                        newBranch.Nodes[i] = branch.Nodes[i];
-                    }
+                        Branch newBranch = new Branch();
+                        newBranch.IsDirty = true;
+                        for (int i = 0; i < 16; i++)
+                        {
+                            newBranch.Nodes[i] = branch.Nodes[i];
+                        }
 
-                    newBranch.Value = branch.Value;
-                    newBranch.Nodes[parentOnStack.PathIndex] = nextNodeRef;
+                        newBranch.Value = branch.Value;
+                        newBranch.Nodes[parentOnStack.PathIndex] = nextNodeRef;
 
-//                    _tree.DeleteNode(branch.Nodes[parentOnStack.PathIndex], true);
-                    if (newBranch.IsValid)
-                    {
                         nextNodeRef = new NodeRef(newBranch, isRoot);
                         nextNode = newBranch;
                     }
                     else
                     {
-                        if (newBranch.Value.Length != 0)
+                        if (branch.Value.Length != 0)
                         {
-                            Leaf leafFromBranch = new Leaf(new HexPrefix(true), newBranch.Value);
+                            Leaf leafFromBranch = new Leaf(new HexPrefix(true), branch.Value);
                             leafFromBranch.IsDirty = true;
                             nextNodeRef = new NodeRef(leafFromBranch, isRoot);
                             nextNode = leafFromBranch;
                         }
                         else
                         {
-                            int childNodeIndex = Array.FindIndex(newBranch.Nodes, n => n != null);
-                            NodeRef childNodeRef = newBranch.Nodes[childNodeIndex];
+                            int childNodeIndex = 0;
+                            for (int i = 0; i < 16; i++)
+                            {
+                                if (i != parentOnStack.PathIndex && branch.Nodes[i] != null)
+                                {
+                                    childNodeIndex = i;
+                                    break;
+                                }
+                            }
+
+                            NodeRef childNodeRef = branch.Nodes[childNodeIndex];
                             if (childNodeRef == null)
                             {
                                 throw new InvalidOperationException("Before updating branch should have had at least two non-empty children");
@@ -270,8 +279,17 @@ namespace Nethermind.Store
 
                 if (_updateValue == null)
                 {
+                    if (node.Value == null)
+                    {
+                        return null;
+                    }
+
                     ConnectNodes(null);
                 }
+                else if (Bytes.UnsafeCompare(_updateValue, node.Value))
+                {
+                    return _updateValue;
+                }
                 else
                 {
                     Branch newBranch = new Branch(node.Nodes, _updateValue);
