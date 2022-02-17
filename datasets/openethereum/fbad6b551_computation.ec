commit fbad6b551434df8c2ddaf91dd5af28e4e3c847a1
Author: debris <marek.kotewicz@gmail.com>
Date:   Mon Oct 16 10:02:26 2017 +0200

    removed redundant mut from kvdb-memorydb

diff --git a/util/kvdb-memorydb/src/lib.rs b/util/kvdb-memorydb/src/lib.rs
index e83bfecf8..6cee7b9b1 100644
--- a/util/kvdb-memorydb/src/lib.rs
+++ b/util/kvdb-memorydb/src/lib.rs
@@ -71,12 +71,12 @@ impl KeyValueDB for InMemory {
 		for op in ops {
 			match op {
 				DBOp::Insert { col, key, value } => {
-					if let Some(mut col) = columns.get_mut(&col) {
+					if let Some(col) = columns.get_mut(&col) {
 						col.insert(key.into_vec(), value);
 					}
 				},
 				DBOp::InsertCompressed { col, key, value } => {
-					if let Some(mut col) = columns.get_mut(&col) {
+					if let Some(col) = columns.get_mut(&col) {
 						let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
 						let mut value = DBValue::new();
 						value.append_slice(&compressed);
@@ -84,7 +84,7 @@ impl KeyValueDB for InMemory {
 					}
 				},
 				DBOp::Delete { col, key } => {
-					if let Some(mut col) = columns.get_mut(&col) {
+					if let Some(col) = columns.get_mut(&col) {
 						col.remove(&*key);
 					}
 				},
