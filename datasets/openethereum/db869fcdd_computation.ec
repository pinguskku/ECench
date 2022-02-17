commit db869fcdd10792de5d618762345d45b94fc4a7f5
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Tue Jun 7 16:18:50 2016 +0200

    remove unnecessary reference

diff --git a/util/src/hash.rs b/util/src/hash.rs
index ab1255e39..6c1f8b2a4 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -559,7 +559,7 @@ impl From<Address> for H256 {
 impl<'a> From<&'a Address> for H256 {
 	fn from(value: &'a Address) -> H256 {
 		let mut ret = H256::new();
-		ret.0[12..32].copy_from_slice(&value);
+		ret.0[12..32].copy_from_slice(value);
 		ret
 	}
 }
