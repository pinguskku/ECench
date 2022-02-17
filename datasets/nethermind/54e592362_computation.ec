commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
commit 54e592362fd94d39d2949fbd0d6bd65cc64c13a7
Author: Tomasz K. Stanczak <tkstanczak@demerzel.co>
Date:   Wed Jun 6 16:48:04 2018 +0100

    test remove unnecessary update root hash

diff --git a/src/Nethermind/Nethermind.Store/PatriciaTree.cs b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
index 9ab29c7b3..5e6eb86d2 100644
--- a/src/Nethermind/Nethermind.Store/PatriciaTree.cs
+++ b/src/Nethermind/Nethermind.Store/PatriciaTree.cs
@@ -130,6 +130,11 @@ namespace Nethermind.Store
 
         private void SetRootHash(Keccak value, bool resetObjects)
         {
+            if (_rootHash == value)
+            {
+                return;
+            }
+
             _rootHash = value;
             if (_rootHash == Keccak.EmptyTreeHash)
             {
diff --git a/src/Nethermind/Nethermind.Store/StateProvider.cs b/src/Nethermind/Nethermind.Store/StateProvider.cs
index e3fa2f002..f23bae151 100644
--- a/src/Nethermind/Nethermind.Store/StateProvider.cs
+++ b/src/Nethermind/Nethermind.Store/StateProvider.cs
@@ -56,8 +56,12 @@ namespace Nethermind.Store
 
         public Keccak StateRoot
         {
-            get => _state.RootHash;
-            set => _state.RootHash = value;
+            get
+            {
+                _state.UpdateRootHash();
+                return _state.RootHash;
+            }
+            set =>_state.RootHash = value;
         }
 
         private readonly StateTree _state;
@@ -437,7 +441,7 @@ namespace Nethermind.Store
             _currentPosition = -1;
             _committedThisRound.Clear();
             _intraBlockCache.Clear();
-            _state.UpdateRootHash();
+            //_state.UpdateRootHash(); // why here?
         }
 
         private Account GetState(Address address)
