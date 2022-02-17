commit 72094a8beec5388bd763eaea7c19f8d6a89c5c01
Author: Jef <jackefransham@gmail.com>
Date:   Wed Jun 28 09:36:42 2017 +0200

    Reduce unnecessary allocations (#5944)

diff --git a/ethcore/src/engines/tendermint/mod.rs b/ethcore/src/engines/tendermint/mod.rs
index 1a462a634..2fc227eaf 100644
--- a/ethcore/src/engines/tendermint/mod.rs
+++ b/ethcore/src/engines/tendermint/mod.rs
@@ -493,8 +493,8 @@ impl Engine for Tendermint {
 		let seal_length = header.seal().len();
 		if seal_length == self.seal_fields() {
 			// Either proposal or commit.
-			if (header.seal()[1] == ::rlp::NULL_RLP.to_vec())
-				!= (header.seal()[2] == ::rlp::EMPTY_LIST_RLP.to_vec()) {
+			if (header.seal()[1] == ::rlp::NULL_RLP)
+				!= (header.seal()[2] == ::rlp::EMPTY_LIST_RLP) {
 				Ok(())
 			} else {
 				warn!(target: "engine", "verify_block_basic: Block is neither a Commit nor Proposal.");
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index 9099ff03b..cf21fbd9f 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -177,7 +177,7 @@ impl JournalDB for ArchiveDB {
 	fn latest_era(&self) -> Option<u64> { self.latest_era }
 
 	fn state(&self, id: &H256) -> Option<Bytes> {
-		self.backing.get_by_prefix(self.column, &id[0..DB_PREFIX_LEN]).map(|b| b.to_vec())
+		self.backing.get_by_prefix(self.column, &id[0..DB_PREFIX_LEN]).map(|b| b.into_vec())
 	}
 
 	fn is_pruned(&self) -> bool { false }
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index 66e5a1cfd..7eb3f3259 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -371,7 +371,7 @@ impl JournalDB for EarlyMergeDB {
  	}
 
 	fn state(&self, id: &H256) -> Option<Bytes> {
-		self.backing.get_by_prefix(self.column, &id[0..DB_PREFIX_LEN]).map(|b| b.to_vec())
+		self.backing.get_by_prefix(self.column, &id[0..DB_PREFIX_LEN]).map(|b| b.into_vec())
 	}
 
 	fn journal_under(&mut self, batch: &mut DBTransaction, now: u64, id: &H256) -> Result<u32, UtilError> {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index af92d3b40..93eec118d 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -244,7 +244,7 @@ impl JournalDB for OverlayRecentDB {
 		let key = to_short_key(key);
 		journal_overlay.backing_overlay.get(&key).map(|v| v.to_vec())
 		.or_else(|| journal_overlay.pending_overlay.get(&key).map(|d| d.clone().to_vec()))
-		.or_else(|| self.backing.get_by_prefix(self.column, &key[0..DB_PREFIX_LEN]).map(|b| b.to_vec()))
+		.or_else(|| self.backing.get_by_prefix(self.column, &key[0..DB_PREFIX_LEN]).map(|b| b.into_vec()))
 	}
 
 	fn journal_under(&mut self, batch: &mut DBTransaction, now: u64, id: &H256) -> Result<u32, UtilError> {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index 13c2189c8..4f8600bde 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -115,7 +115,7 @@ impl JournalDB for RefCountedDB {
 	fn latest_era(&self) -> Option<u64> { self.latest_era }
 
 	fn state(&self, id: &H256) -> Option<Bytes> {
-		self.backing.get_by_prefix(self.column, &id[0..DB_PREFIX_LEN]).map(|b| b.to_vec())
+		self.backing.get_by_prefix(self.column, &id[0..DB_PREFIX_LEN]).map(|b| b.into_vec())
 	}
 
 	fn journal_under(&mut self, batch: &mut DBTransaction, now: u64, id: &H256) -> Result<u32, UtilError> {
