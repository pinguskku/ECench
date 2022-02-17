commit cd3a1c1a94ed99819c6b9512d1af9b5b7f5830ef
Author: Guanqun Lu <guanqun.lu@gmail.com>
Date:   Fri Jun 9 01:26:46 2017 +0800

    use rust 1.18's new feature to boost the purge performance

diff --git a/README.md b/README.md
index b286055b2..07f0423f1 100644
--- a/README.md
+++ b/README.md
@@ -53,7 +53,7 @@ below to build from source.
 
 ## Build dependencies
 
-**Parity requires Rust version 1.17.0 to build**
+**Parity requires Rust version 1.18.0 to build**
 
 We recommend installing Rust through [rustup](https://www.rustup.rs/). If you don't already have rustup, you can install it like this:
 
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index 1feca9cba..bd96347ab 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -103,11 +103,7 @@ impl MemoryDB {
 
 	/// Purge all zero-referenced data from the database.
 	pub fn purge(&mut self) {
-		let empties: Vec<_> = self.data.iter()
-			.filter(|&(_, &(_, rc))| rc == 0)
-			.map(|(k, _)| k.clone())
-			.collect();
-		for empty in empties { self.data.remove(&empty); }
+		self.data.retain(|_, &mut (_, rc)| rc != 0);
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
