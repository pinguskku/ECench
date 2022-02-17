commit 581b320b9dfb42c0c4842e0bc5aeb507267a8eba
Author: Nick Johnson <arachnid@notdot.net>
Date:   Mon Sep 19 07:56:23 2016 +0800

    core/state: Fix memory expansion bug by not copying clean objects

diff --git a/core/state/state_object.go b/core/state/state_object.go
index 769c63d42..20da1006f 100644
--- a/core/state/state_object.go
+++ b/core/state/state_object.go
@@ -187,7 +187,7 @@ func (self *StateObject) Copy() *StateObject {
 	stateObject.codeHash = common.CopyBytes(self.codeHash)
 	stateObject.nonce = self.nonce
 	stateObject.trie = self.trie
-	stateObject.code = common.CopyBytes(self.code)
+	stateObject.code = self.code
 	stateObject.initCode = common.CopyBytes(self.initCode)
 	stateObject.storage = self.storage.Copy()
 	stateObject.remove = self.remove
diff --git a/core/state/state_test.go b/core/state/state_test.go
index ce86a5b76..5a6cb0b50 100644
--- a/core/state/state_test.go
+++ b/core/state/state_test.go
@@ -149,10 +149,11 @@ func TestSnapshot2(t *testing.T) {
 	so0.balance = big.NewInt(42)
 	so0.nonce = 43
 	so0.SetCode([]byte{'c', 'a', 'f', 'e'})
-	so0.remove = true
+	so0.remove = false
 	so0.deleted = false
-	so0.dirty = false
+	so0.dirty = true
 	state.SetStateObject(so0)
+	state.Commit()
 
 	// and one with deleted == true
 	so1 := state.GetStateObject(stateobjaddr1)
@@ -173,6 +174,7 @@ func TestSnapshot2(t *testing.T) {
 	state.Set(snapshot)
 
 	so0Restored := state.GetStateObject(stateobjaddr0)
+	so0Restored.GetState(storageaddr)
 	so1Restored := state.GetStateObject(stateobjaddr1)
 	// non-deleted is equal (restored)
 	compareStateObjects(so0Restored, so0, t)
diff --git a/core/state/statedb.go b/core/state/statedb.go
index 3e25e0c16..8ba81613d 100644
--- a/core/state/statedb.go
+++ b/core/state/statedb.go
@@ -324,7 +324,9 @@ func (self *StateDB) Copy() *StateDB {
 	state, _ := New(common.Hash{}, self.db)
 	state.trie = self.trie
 	for k, stateObject := range self.stateObjects {
-		state.stateObjects[k] = stateObject.Copy()
+		if stateObject.dirty {
+			state.stateObjects[k] = stateObject.Copy()
+		}
 	}
 
 	state.refund.Set(self.refund)
@@ -364,7 +366,6 @@ func (s *StateDB) IntermediateRoot() common.Hash {
 				stateObject.Update()
 				s.UpdateStateObject(stateObject)
 			}
-			stateObject.dirty = false
 		}
 	}
 	return s.trie.Hash()
