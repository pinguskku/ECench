commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
commit 22eea17b0672fc8be84b655f995f3f2555446c5e
Author: Gustav Simonsson <gustav.simonsson@gmail.com>
Date:   Mon Sep 19 02:13:14 2016 -0400

    light: fix memory expansion bug (same as fix for core/state)

diff --git a/light/state.go b/light/state.go
index e18f9cdc5..4f2177238 100644
--- a/light/state.go
+++ b/light/state.go
@@ -261,7 +261,9 @@ func (self *LightState) Copy() *LightState {
 	state := NewLightState(common.Hash{}, self.odr)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	return state
diff --git a/light/state_object.go b/light/state_object.go
index 08c209d7d..1e9c7f4b1 100644
--- a/light/state_object.go
+++ b/light/state_object.go
@@ -186,7 +186,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
 	stateObject.dirty = self.dirty
