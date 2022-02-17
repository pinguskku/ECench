commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
commit 4e447ccc681ce378a05546e5f69751fb5afc3a4e
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Tue Jul 19 09:23:53 2016 +0200

    More performance optimizations (#1649)
    
    * Use tree index for DB
    
    * Set uncles_hash, tx_root, receipts_root from verified block
    
    * Use Filth instead of a bool
    
    * Fix empty root check
    
    * Flush block queue properly
    
    * Expunge deref

diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 3204eddcd..ff7bfe70d 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -36,7 +36,7 @@ pub struct Account {
 	// Code cache of the account.
 	code_cache: Bytes,
 	// Account is new or has been modified
-	dirty: bool,
+	filth: Filth,
 }
 
 impl Account {
@@ -50,7 +50,7 @@ impl Account {
 			storage_overlay: RefCell::new(storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(code.sha3()),
 			code_cache: code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -63,7 +63,7 @@ impl Account {
 			storage_overlay: RefCell::new(pod.storage.into_iter().map(|(k, v)| (k, (Filth::Dirty, v))).collect()),
 			code_hash: Some(pod.code.sha3()),
 			code_cache: pod.code,
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -76,7 +76,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(SHA3_EMPTY),
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -90,7 +90,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: Some(r.val_at(3)),
 			code_cache: vec![],
-			dirty: false,
+			filth: Filth::Clean,
 		}
 	}
 
@@ -104,7 +104,7 @@ impl Account {
 			storage_overlay: RefCell::new(HashMap::new()),
 			code_hash: None,
 			code_cache: vec![],
-			dirty: true,
+			filth: Filth::Dirty,
 		}
 	}
 
@@ -113,7 +113,7 @@ impl Account {
 	pub fn init_code(&mut self, code: Bytes) {
 		assert!(self.code_hash.is_none());
 		self.code_cache = code;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Reset this account's code to the given code.
@@ -125,7 +125,7 @@ impl Account {
 	/// Set (and cache) the contents of the trie's storage at `key` to `value`.
 	pub fn set_storage(&mut self, key: H256, value: H256) {
 		self.storage_overlay.borrow_mut().insert(key, (Filth::Dirty, value));
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Get (and cache) the contents of the trie's storage at `key`.
@@ -183,7 +183,7 @@ impl Account {
 
 	/// Is this a new or modified account?
 	pub fn is_dirty(&self) -> bool {
-		self.dirty
+		self.filth == Filth::Dirty
 	}
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
@@ -216,13 +216,13 @@ impl Account {
 	/// Increment the nonce of the account by one.
 	pub fn inc_nonce(&mut self) {
 		self.nonce = self.nonce + U256::from(1u8);
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
 	pub fn add_balance(&mut self, x: &U256) {
 		self.balance = self.balance + *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Increment the nonce of the account by one.
@@ -230,7 +230,7 @@ impl Account {
 	pub fn sub_balance(&mut self, x: &U256) {
 		assert!(self.balance >= *x);
 		self.balance = self.balance - *x;
-		self.dirty = true;
+		self.filth = Filth::Dirty;
 	}
 
 	/// Commit the `storage_overlay` to the backing DB and update `storage_root`.
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 833e70c08..2be475410 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -275,6 +275,15 @@ impl<'x> OpenBlock<'x> {
 	/// Alter the gas limit for the block.
 	pub fn set_gas_used(&mut self, a: U256) { self.block.base.header.set_gas_used(a); }
 
+	/// Alter the uncles hash the block.
+	pub fn set_uncles_hash(&mut self, h: H256) { self.block.base.header.set_uncles_hash(h); }
+
+	/// Alter transactions root for the block.
+	pub fn set_transactions_root(&mut self, h: H256) { self.block.base.header.set_transactions_root(h); }
+
+	/// Alter the receipts root for the block.
+	pub fn set_receipts_root(&mut self, h: H256) { self.block.base.header.set_receipts_root(h); }
+
 	/// Alter the extra_data for the block.
 	pub fn set_extra_data(&mut self, extra_data: Bytes) -> Result<(), BlockError> {
 		if extra_data.len() > self.engine.maximum_extra_data_size() {
@@ -365,11 +374,17 @@ impl<'x> OpenBlock<'x> {
 		let mut s = self;
 
 		s.engine.on_close_block(&mut s.block);
-		s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		if s.block.base.header.transactions_root.is_zero() || s.block.base.header.transactions_root == SHA3_NULL_RLP {
+			s.block.base.header.transactions_root = ordered_trie_root(s.block.base.transactions.iter().map(|ref e| e.rlp_bytes().to_vec()).collect());
+		}
 		let uncle_bytes = s.block.base.uncles.iter().fold(RlpStream::new_list(s.block.base.uncles.len()), |mut s, u| {s.append_raw(&u.rlp(Seal::With), 1); s} ).out();
-		s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		if s.block.base.header.uncles_hash.is_zero() {
+			s.block.base.header.uncles_hash = uncle_bytes.sha3();
+		}
+		if s.block.base.header.receipts_root.is_zero() || s.block.base.header.receipts_root == SHA3_NULL_RLP {
+			s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
+		}
 		s.block.base.header.state_root = s.block.state.root().clone();
-		s.block.base.header.receipts_root = ordered_trie_root(s.block.receipts.iter().map(|ref r| r.rlp_bytes().to_vec()).collect());
 		s.block.base.header.log_bloom = s.block.receipts.iter().fold(LogBloom::zero(), |mut b, r| {b = &b | &r.log_bloom; b}); //TODO: use |= operator
 		s.block.base.header.gas_used = s.block.receipts.last().map_or(U256::zero(), |r| r.gas_used);
 		s.block.base.header.note_dirty();
@@ -500,6 +515,9 @@ pub fn enact(
 	b.set_timestamp(header.timestamp());
 	b.set_author(header.author().clone());
 	b.set_extra_data(header.extra_data().clone()).unwrap_or_else(|e| warn!("Couldn't set extradata: {}. Ignoring.", e));
+	b.set_uncles_hash(header.uncles_hash().clone());
+	b.set_transactions_root(header.transactions_root().clone());
+	b.set_receipts_root(header.receipts_root().clone());
 	for t in transactions { try!(b.push_transaction(t.clone(), None)); }
 	for u in uncles { try!(b.push_uncle(u.clone())); }
 	Ok(b.close_and_lock())
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 4d27e8daf..fcea93b29 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -445,8 +445,8 @@ impl BlockChain {
 		let mut from_branch = vec![];
 		let mut to_branch = vec![];
 
-		let mut from_details = self.block_details(&from).expect(&format!("0. Expected to find details for block {:?}", from));
-		let mut to_details = self.block_details(&to).expect(&format!("1. Expected to find details for block {:?}", to));
+		let mut from_details = self.block_details(&from).unwrap_or_else(|| panic!("0. Expected to find details for block {:?}", from));
+		let mut to_details = self.block_details(&to).unwrap_or_else(|| panic!("1. Expected to find details for block {:?}", to));
 		let mut current_from = from;
 		let mut current_to = to;
 
@@ -454,13 +454,13 @@ impl BlockChain {
 		while from_details.number > to_details.number {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("2. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("2. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		while to_details.number > from_details.number {
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("3. Expected to find details for block {:?}", to_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("3. Expected to find details for block {:?}", to_details.parent));
 		}
 
 		assert_eq!(from_details.number, to_details.number);
@@ -469,11 +469,11 @@ impl BlockChain {
 		while current_from != current_to {
 			from_branch.push(current_from);
 			current_from = from_details.parent.clone();
-			from_details = self.block_details(&from_details.parent).expect(&format!("4. Expected to find details for block {:?}", from_details.parent));
+			from_details = self.block_details(&from_details.parent).unwrap_or_else(|| panic!("4. Expected to find details for block {:?}", from_details.parent));
 
 			to_branch.push(current_to);
 			current_to = to_details.parent.clone();
-			to_details = self.block_details(&to_details.parent).expect(&format!("5. Expected to find details for block {:?}", from_details.parent));
+			to_details = self.block_details(&to_details.parent).unwrap_or_else(|| panic!("5. Expected to find details for block {:?}", from_details.parent));
 		}
 
 		let index = from_branch.len();
@@ -613,7 +613,7 @@ impl BlockChain {
 		let hash = block.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
-		let parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		let total_difficulty = parent_details.total_difficulty + header.difficulty();
 		let is_new_best = total_difficulty > self.best_block_total_difficulty();
 
@@ -682,7 +682,7 @@ impl BlockChain {
 		let parent_hash = header.parent_hash();
 
 		// update parent
-		let mut parent_details = self.block_details(&parent_hash).expect(format!("Invalid parent hash: {:?}", parent_hash).as_ref());
+		let mut parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
 		parent_details.children.push(info.hash.clone());
 
 		// create current block details
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index e9421b64c..0b11d1837 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -252,6 +252,9 @@ impl Client {
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
 		self.block_queue.flush();
+		while !self.block_queue.queue_info().is_empty() {
+			self.import_verified_blocks(&IoChannel::disconnected());
+		}
 	}
 
 	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
diff --git a/ethcore/src/header.rs b/ethcore/src/header.rs
index 48a5f5bcc..d5272ce2e 100644
--- a/ethcore/src/header.rs
+++ b/ethcore/src/header.rs
@@ -18,7 +18,7 @@
 
 use util::*;
 use basic_types::*;
-use time::now_utc;
+use time::get_time;
 
 /// Type for Block number
 pub type BlockNumber = u64;
@@ -137,6 +137,10 @@ impl Header {
 	pub fn state_root(&self) -> &H256 { &self.state_root }
 	/// Get the receipts root field of the header.
 	pub fn receipts_root(&self) -> &H256 { &self.receipts_root }
+	/// Get the transactions root field of the header.
+	pub fn transactions_root(&self) -> &H256 { &self.transactions_root }
+	/// Get the uncles hash field of the header.
+	pub fn uncles_hash(&self) -> &H256 { &self.uncles_hash }
 	/// Get the gas limit field of the header.
 	pub fn gas_limit(&self) -> &U256 { &self.gas_limit }
 
@@ -162,7 +166,7 @@ impl Header {
 	/// Set the timestamp field of the header.
 	pub fn set_timestamp(&mut self, a: u64) { self.timestamp = a; self.note_dirty(); }
 	/// Set the timestamp field of the header to the current time.
-	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(now_utc().to_timespec().sec as u64, but_later_than + 1); self.note_dirty(); }
+	pub fn set_timestamp_now(&mut self, but_later_than: u64) { self.timestamp = max(get_time().sec as u64, but_later_than + 1); self.note_dirty(); }
 	/// Set the number field of the header.
 	pub fn set_number(&mut self, a: BlockNumber) { self.number = a; self.note_dirty(); }
 	/// Set the author field of the header.
diff --git a/parity/main.rs b/parity/main.rs
index 89ca051a2..ba1535689 100644
--- a/parity/main.rs
+++ b/parity/main.rs
@@ -447,7 +447,7 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			Err(BlockImportError::Import(ImportError::AlreadyInChain)) => { trace!("Skipping block already in chain."); }
 			Err(e) => die!("Cannot import block: {:?}", e)
 		}
-		informant.tick(client.deref(), None);
+		informant.tick(&*client, None);
 	};
 
 	match format {
@@ -473,6 +473,10 @@ fn execute_import(conf: Configuration, panic_handler: Arc<PanicHandler>) {
 			}
 		}
 	}
+	while !client.queue_info().is_empty() {
+		sleep(Duration::from_secs(1));
+		informant.tick(&*client, None);
+	}
 	client.flush_queue();
 }
 
diff --git a/util/src/journaldb/archivedb.rs b/util/src/journaldb/archivedb.rs
index e70134c22..4bf377cf7 100644
--- a/util/src/journaldb/archivedb.rs
+++ b/util/src/journaldb/archivedb.rs
@@ -49,8 +49,7 @@ pub struct ArchiveDB {
 impl ArchiveDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> ArchiveDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/earlymergedb.rs b/util/src/journaldb/earlymergedb.rs
index e976576bc..45e9202b4 100644
--- a/util/src/journaldb/earlymergedb.rs
+++ b/util/src/journaldb/earlymergedb.rs
@@ -74,8 +74,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl EarlyMergeDB {
 	/// Create a new instance from file
 	pub fn new(path: &str, config: DatabaseConfig) -> EarlyMergeDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index 3a33ea9b2..a4d3005a8 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -104,8 +104,7 @@ impl OverlayRecentDB {
 
 	/// Create a new instance from file
 	pub fn from_prefs(path: &str, config: DatabaseConfig) -> OverlayRecentDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/journaldb/refcounteddb.rs b/util/src/journaldb/refcounteddb.rs
index aea6f16ad..b50fc2a72 100644
--- a/util/src/journaldb/refcounteddb.rs
+++ b/util/src/journaldb/refcounteddb.rs
@@ -47,8 +47,7 @@ const PADDING : [u8; 10] = [ 0u8; 10 ];
 impl RefCountedDB {
 	/// Create a new instance given a `backing` database.
 	pub fn new(path: &str, config: DatabaseConfig) -> RefCountedDB {
-		let opts = config.prefix(DB_PREFIX_LEN);
-		let backing = Database::open(&opts, path).unwrap_or_else(|e| {
+		let backing = Database::open(&config, path).unwrap_or_else(|e| {
 			panic!("Error opening state db: {}", e);
 		});
 		if !backing.is_empty() {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index 729583c52..b4477e240 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -18,7 +18,7 @@
 
 use std::default::Default;
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
-	IndexType, Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -83,8 +83,6 @@ impl CompactionProfile {
 
 /// Database configuration
 pub struct DatabaseConfig {
-	/// Optional prefix size in bytes. Allows lookup by partial key.
-	pub prefix_size: Option<usize>,
 	/// Max number of open files.
 	pub max_open_files: i32,
 	/// Cache-size
@@ -98,7 +96,6 @@ impl DatabaseConfig {
 	pub fn with_cache(cache_size: usize) -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: Some(cache_size),
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -109,19 +106,12 @@ impl DatabaseConfig {
 		self.compaction = profile;
 		self
 	}
-
-	/// Modify the prefix of the db
-	pub fn prefix(mut self, prefix_size: usize) -> Self {
-		self.prefix_size = Some(prefix_size);
-		self
-	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
 			cache_size: None,
-			prefix_size: None,
 			max_open_files: 256,
 			compaction: CompactionProfile::default(),
 		}
@@ -171,17 +161,9 @@ impl Database {
 		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
 		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
 
-		if let Some(size) = config.prefix_size {
+		if let Some(cache_size) = config.cache_size {
 			let mut block_opts = BlockBasedOptions::new();
-			block_opts.set_index_type(IndexType::HashSearch);
-			opts.set_block_based_table_factory(&block_opts);
-			opts.set_prefix_extractor_fixed_size(size);
-			if let Some(cache_size) = config.cache_size {
-				block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-			}
-		} else if let Some(cache_size) = config.cache_size {
-			let mut block_opts = BlockBasedOptions::new();
-			// half goes to read cache
+			// all goes to read cache
 			block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
 			opts.set_block_based_table_factory(&block_opts);
 		}
@@ -281,10 +263,8 @@ mod tests {
 		assert!(db.get(&key1).unwrap().is_none());
 		assert_eq!(db.get(&key3).unwrap().unwrap().deref(), b"elephant");
 
-		if config.prefix_size.is_some() {
-			assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
-			assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
-		}
+		assert_eq!(db.get_by_prefix(&key3).unwrap().deref(), b"elephant");
+		assert_eq!(db.get_by_prefix(&key2).unwrap().deref(), b"dog");
 	}
 
 	#[test]
@@ -293,9 +273,6 @@ mod tests {
 		let smoke = Database::open_default(path.as_path().to_str().unwrap()).unwrap();
 		assert!(smoke.is_empty());
 		test_db(&DatabaseConfig::default());
-		test_db(&DatabaseConfig::default().prefix(12));
-		test_db(&DatabaseConfig::default().prefix(22));
-		test_db(&DatabaseConfig::default().prefix(8));
 	}
 }
 
diff --git a/util/src/migration/mod.rs b/util/src/migration/mod.rs
index 048441d7d..d71d26885 100644
--- a/util/src/migration/mod.rs
+++ b/util/src/migration/mod.rs
@@ -197,7 +197,6 @@ impl Manager {
 		let config = self.config.clone();
 		let migrations = try!(self.migrations_from(version).ok_or(Error::MigrationImpossible));
 		let db_config = DatabaseConfig {
-			prefix_size: None,
 			max_open_files: 64,
 			cache_size: None,
 			compaction: CompactionProfile::default(),
