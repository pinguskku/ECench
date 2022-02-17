commit cddc33bb24edf5e8b5d9052338965247829c5f4b
Author: Wei Tang <accounts@that.world>
Date:   Thu May 10 00:41:56 2018 +0800

    Remove unnecessary cloning in overwrite_with (#8580)
    
    * Remove unnecessary cloning in overwrite_with
    
    * Remove into_iter

diff --git a/ethcore/src/state/account.rs b/ethcore/src/state/account.rs
index ff7d70bd3..5c1dd4039 100644
--- a/ethcore/src/state/account.rs
+++ b/ethcore/src/state/account.rs
@@ -460,7 +460,7 @@ impl Account {
 		self.address_hash = other.address_hash;
 		let mut cache = self.storage_cache.borrow_mut();
 		for (k, v) in other.storage_cache.into_inner() {
-			cache.insert(k.clone() , v.clone()); //TODO: cloning should not be required here
+			cache.insert(k, v);
 		}
 		self.storage_changes = other.storage_changes;
 	}
