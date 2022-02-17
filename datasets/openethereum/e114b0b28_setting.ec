commit e114b0b28d33e89342c4077da74d944fa175ebda
Author: André Silva <andre.beat@gmail.com>
Date:   Wed Jan 3 10:00:37 2018 +0000

    Upgrade to RocksDB 5.8.8 and tune settings to reduce space amplification (#7348)
    
    * kvdb-rocksdb: update to RocksDB 5.8.8
    
    * kvdb-rocksdb: tune RocksDB options
    
    * Switch to level-style compaction
    * Increase default block size (16K), and use bigger blocks for HDDs (64K)
    * Increase default file size base (64MB SSDs, 256MB HDDs)
    * Create a single block cache shared across all column families
    * Tune compaction settings using RocksDB helper functions, taking into account
      memory budget spread across all columns
    * Configure backgrounds jobs based on the number of CPUs
    * Set some default recommended settings
    
    * ethcore: remove unused config blockchain.db_cache_size
    
    * parity: increase default value for db_cache_size
    
    * kvdb-rocksdb: enable compression on all levels
    
    * kvdb-rocksdb: set global db_write_bufer_size
    
    * kvdb-rocksdb: reduce db_write_bufer_size to force earlier flushing
    
    * kvdb-rocksdb: use master branch for rust-rocksdb dependency

diff --git a/Cargo.lock b/Cargo.lock
index 56fc9cfe9..9d362a664 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -204,6 +204,9 @@ dependencies = [
 name = "cc"
 version = "1.0.0"
 source = "registry+https://github.com/rust-lang/crates.io-index"
+dependencies = [
+ "rayon 0.8.2 (registry+https://github.com/rust-lang/crates.io-index)",
+]
 
 [[package]]
 name = "cfg-if"
@@ -1361,6 +1364,7 @@ dependencies = [
  "interleaved-ordered 0.1.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "kvdb 0.1.0",
  "log 0.3.8 (registry+https://github.com/rust-lang/crates.io-index)",
+ "num_cpus 1.7.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "parking_lot 0.4.8 (registry+https://github.com/rust-lang/crates.io-index)",
  "regex 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "rlp 0.2.1",
@@ -2654,7 +2658,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/paritytech/rust-rocksdb#8c4ad5411c141abc63d562d411053f7ebc1aa00c"
+source = "git+https://github.com/paritytech/rust-rocksdb#166e14ed63cbd2e44b51267b8b98e4b89b0f236f"
 dependencies = [
  "libc 0.2.31 (registry+https://github.com/rust-lang/crates.io-index)",
  "local-encoding 0.2.0 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -2664,9 +2668,9 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/paritytech/rust-rocksdb#8c4ad5411c141abc63d562d411053f7ebc1aa00c"
+source = "git+https://github.com/paritytech/rust-rocksdb#166e14ed63cbd2e44b51267b8b98e4b89b0f236f"
 dependencies = [
- "gcc 0.3.54 (registry+https://github.com/rust-lang/crates.io-index)",
+ "cc 1.0.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.31 (registry+https://github.com/rust-lang/crates.io-index)",
  "snappy-sys 0.1.0 (git+https://github.com/paritytech/rust-snappy)",
 ]
diff --git a/ethcore/light/src/client/service.rs b/ethcore/light/src/client/service.rs
index b28169c5d..253eef7f5 100644
--- a/ethcore/light/src/client/service.rs
+++ b/ethcore/light/src/client/service.rs
@@ -64,11 +64,7 @@ impl<T: ChainDataFetcher> Service<T> {
 		// initialize database.
 		let mut db_config = DatabaseConfig::with_columns(db::NUM_COLUMNS);
 
-		// give all rocksdb cache to the header chain column.
-		if let Some(size) = config.db_cache_size {
-			db_config.set_cache(db::COL_LIGHT_CHAIN, size);
-		}
-
+		db_config.memory_budget = config.db_cache_size;
 		db_config.compaction = config.db_compaction;
 		db_config.wal = config.db_wal;
 
diff --git a/ethcore/src/blockchain/config.rs b/ethcore/src/blockchain/config.rs
index 4be606b33..312289b06 100644
--- a/ethcore/src/blockchain/config.rs
+++ b/ethcore/src/blockchain/config.rs
@@ -23,8 +23,6 @@ pub struct Config {
 	pub pref_cache_size: usize,
 	/// Maximum cache size in bytes.
 	pub max_cache_size: usize,
-	/// Backing db cache_size
-	pub db_cache_size: Option<usize>,
 }
 
 impl Default for Config {
@@ -32,8 +30,6 @@ impl Default for Config {
 		Config {
 			pref_cache_size: 1 << 14,
 			max_cache_size: 1 << 20,
-			db_cache_size: None,
 		}
 	}
 }
-
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index ce5878f1e..3c26c4621 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -141,7 +141,7 @@ pub struct ClientConfig {
 	pub pruning: journaldb::Algorithm,
 	/// The name of the client instance.
 	pub name: String,
-	/// RocksDB state column cache-size if not default
+	/// RocksDB column cache-size if not default
 	pub db_cache_size: Option<usize>,
 	/// State db compaction profile
 	pub db_compaction: DatabaseCompactionProfile,
diff --git a/ethcore/src/service.rs b/ethcore/src/service.rs
index a4b5b22f6..ea0a1ffd4 100644
--- a/ethcore/src/service.rs
+++ b/ethcore/src/service.rs
@@ -79,12 +79,7 @@ impl ClientService {
 
 		let mut db_config = DatabaseConfig::with_columns(::db::NUM_COLUMNS);
 
-		// give all rocksdb cache to state column; everything else has its
-		// own caches.
-		if let Some(size) = config.db_cache_size {
-			db_config.set_cache(::db::COL_STATE, size);
-		}
-
+		db_config.memory_budget = config.db_cache_size;
 		db_config.compaction = config.db_compaction.compaction_profile(client_path);
 		db_config.wal = config.db_wal;
 
diff --git a/parity/cache.rs b/parity/cache.rs
index 8784ffa3d..0bf0717a3 100644
--- a/parity/cache.rs
+++ b/parity/cache.rs
@@ -17,8 +17,10 @@
 use std::cmp::max;
 
 const MIN_BC_CACHE_MB: u32 = 4;
-const MIN_DB_CACHE_MB: u32 = 2;
+const MIN_DB_CACHE_MB: u32 = 8;
 const MIN_BLOCK_QUEUE_SIZE_LIMIT_MB: u32 = 16;
+const DEFAULT_DB_CACHE_SIZE: u32 = 128;
+const DEFAULT_BC_CACHE_SIZE: u32 = 8;
 const DEFAULT_BLOCK_QUEUE_SIZE_LIMIT_MB: u32 = 40;
 const DEFAULT_TRACE_CACHE_SIZE: u32 = 20;
 const DEFAULT_STATE_CACHE_SIZE: u32 = 25;
@@ -41,7 +43,11 @@ pub struct CacheConfig {
 
 impl Default for CacheConfig {
 	fn default() -> Self {
-		CacheConfig::new(32, 8, DEFAULT_BLOCK_QUEUE_SIZE_LIMIT_MB, DEFAULT_STATE_CACHE_SIZE)
+		CacheConfig::new(
+			DEFAULT_DB_CACHE_SIZE,
+			DEFAULT_BC_CACHE_SIZE,
+			DEFAULT_BLOCK_QUEUE_SIZE_LIMIT_MB,
+			DEFAULT_STATE_CACHE_SIZE)
 	}
 }
 
@@ -68,14 +74,9 @@ impl CacheConfig {
 		}
 	}
 
-	/// Size of db cache for blockchain.
-	pub fn db_blockchain_cache_size(&self) -> u32 {
-		max(MIN_DB_CACHE_MB, self.db / 4)
-	}
-
-	/// Size of db cache for state.
-	pub fn db_state_cache_size(&self) -> u32 {
-		max(MIN_DB_CACHE_MB, self.db * 3 / 4)
+	/// Size of db cache.
+	pub fn db_cache_size(&self) -> u32 {
+		max(MIN_DB_CACHE_MB, self.db)
 	}
 
 	/// Size of block queue size limit
@@ -122,13 +123,16 @@ mod tests {
 	fn test_cache_config_db_cache_sizes() {
 		let config = CacheConfig::new_with_total_cache_size(400);
 		assert_eq!(config.db, 280);
-		assert_eq!(config.db_blockchain_cache_size(), 70);
-		assert_eq!(config.db_state_cache_size(), 210);
+		assert_eq!(config.db_cache_size(), 280);
 	}
 
 	#[test]
 	fn test_cache_config_default() {
 		assert_eq!(CacheConfig::default(),
-			CacheConfig::new(32, 8, super::DEFAULT_BLOCK_QUEUE_SIZE_LIMIT_MB, super::DEFAULT_STATE_CACHE_SIZE));
+				   CacheConfig::new(
+					   super::DEFAULT_DB_CACHE_SIZE,
+					   super::DEFAULT_BC_CACHE_SIZE,
+					   super::DEFAULT_BLOCK_QUEUE_SIZE_LIMIT_MB,
+					   super::DEFAULT_STATE_CACHE_SIZE));
 	}
 }
diff --git a/parity/cli/mod.rs b/parity/cli/mod.rs
index 445e75d1b..76f36d0ec 100644
--- a/parity/cli/mod.rs
+++ b/parity/cli/mod.rs
@@ -779,7 +779,7 @@ usage! {
 			"--pruning-memory=[MB]",
 			"The ideal amount of memory in megabytes to use to store recent states. As many states as possible will be kept within this limit, and at least --pruning-history states will always be kept.",
 
-			ARG arg_cache_size_db: (u32) = 32u32, or |c: &Config| otry!(c.footprint).cache_size_db.clone(),
+			ARG arg_cache_size_db: (u32) = 128u32, or |c: &Config| otry!(c.footprint).cache_size_db.clone(),
 			"--cache-size-db=[MB]",
 			"Override database cache size.",
 
@@ -1797,7 +1797,7 @@ mod tests {
 				pruning_memory: None,
 				fast_and_loose: None,
 				cache_size: None,
-				cache_size_db: Some(128),
+				cache_size_db: Some(256),
 				cache_size_blocks: Some(16),
 				cache_size_queue: Some(100),
 				cache_size_state: Some(25),
diff --git a/parity/cli/tests/config.toml b/parity/cli/tests/config.toml
index 08da653de..abdf3e0c7 100644
--- a/parity/cli/tests/config.toml
+++ b/parity/cli/tests/config.toml
@@ -63,7 +63,7 @@ tx_queue_gas = "off"
 tracing = "on"
 pruning = "fast"
 pruning_history = 64
-cache_size_db = 128
+cache_size_db = 256
 cache_size_blocks = 16
 cache_size_queue = 100
 cache_size_state = 25
diff --git a/parity/helpers.rs b/parity/helpers.rs
index 5283b47c8..4cca58877 100644
--- a/parity/helpers.rs
+++ b/parity/helpers.rs
@@ -227,10 +227,8 @@ pub fn to_client_config(
 	client_config.blockchain.max_cache_size = cache_config.blockchain() as usize * mb;
 	// in bytes
 	client_config.blockchain.pref_cache_size = cache_config.blockchain() as usize * 3 / 4 * mb;
-	// db blockchain cache size, in megabytes
-	client_config.blockchain.db_cache_size = Some(cache_config.db_blockchain_cache_size() as usize);
-	// db state cache size, in megabytes
-	client_config.db_cache_size = Some(cache_config.db_state_cache_size() as usize);
+	// db cache size, in megabytes
+	client_config.db_cache_size = Some(cache_config.db_cache_size() as usize);
 	// db queue cache size, in bytes
 	client_config.queue.max_mem_use = cache_config.queue() as usize * mb;
 	// in bytes
diff --git a/parity/migration.rs b/parity/migration.rs
index 63385e033..df91c2624 100644
--- a/parity/migration.rs
+++ b/parity/migration.rs
@@ -168,7 +168,7 @@ fn consolidate_database(
 	let config = default_migration_settings(compaction_profile);
 	let mut db_config = DatabaseConfig {
 		max_open_files: 64,
-		cache_sizes: Default::default(),
+		memory_budget: None,
 		compaction: config.compaction_profile,
 		columns: None,
 		wal: true,
diff --git a/util/kvdb-rocksdb/Cargo.toml b/util/kvdb-rocksdb/Cargo.toml
index f2eb569dc..1e81d1dfb 100644
--- a/util/kvdb-rocksdb/Cargo.toml
+++ b/util/kvdb-rocksdb/Cargo.toml
@@ -8,6 +8,7 @@ elastic-array = "0.9"
 ethcore-bigint = { path = "../bigint" }
 kvdb = { path = "../kvdb" }
 log = "0.3"
+num_cpus = "1.0"
 parking_lot = "0.4"
 regex = "0.2"
 rlp = { path = "../rlp" }
diff --git a/util/kvdb-rocksdb/src/lib.rs b/util/kvdb-rocksdb/src/lib.rs
index cae3b6be4..3f5fdd1e2 100644
--- a/util/kvdb-rocksdb/src/lib.rs
+++ b/util/kvdb-rocksdb/src/lib.rs
@@ -18,15 +18,17 @@
 extern crate log;
 
 extern crate elastic_array;
+extern crate interleaved_ordered;
+extern crate num_cpus;
 extern crate parking_lot;
 extern crate regex;
 extern crate rocksdb;
-extern crate interleaved_ordered;
 
 extern crate ethcore_bigint as bigint;
 extern crate kvdb;
 extern crate rlp;
 
+use std::cmp;
 use std::collections::HashMap;
 use std::marker::PhantomData;
 use std::path::{PathBuf, Path};
@@ -35,7 +37,7 @@ use std::{mem, fs, io};
 use parking_lot::{Mutex, MutexGuard, RwLock};
 use rocksdb::{
 	DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions
+	Options, BlockBasedOptions, Direction, Cache, Column, ReadOptions
 };
 use interleaved_ordered::{interleave_ordered, InterleaveOrdered};
 
@@ -50,9 +52,7 @@ use std::process::Command;
 #[cfg(target_os = "linux")]
 use std::fs::File;
 
-const DB_BACKGROUND_FLUSHES: i32 = 2;
-const DB_BACKGROUND_COMPACTIONS: i32 = 2;
-const DB_WRITE_BUFFER_SIZE: usize = 2048 * 1000;
+const DB_DEFAULT_MEMORY_BUDGET_MB: usize = 128;
 
 enum KeyState {
 	Insert(DBValue),
@@ -65,8 +65,8 @@ enum KeyState {
 pub struct CompactionProfile {
 	/// L0-L1 target file size
 	pub initial_file_size: u64,
-	/// L2-LN target file size multiplier
-	pub file_size_multiplier: i32,
+	/// block size
+	pub block_size: usize,
 	/// rate limiter for background flushes and compactions, bytes/sec, if any
 	pub write_rate_limit: Option<u64>,
 }
@@ -136,8 +136,8 @@ impl CompactionProfile {
 	/// Default profile suitable for SSD storage
 	pub fn ssd() -> CompactionProfile {
 		CompactionProfile {
-			initial_file_size: 32 * 1024 * 1024,
-			file_size_multiplier: 2,
+			initial_file_size: 64 * 1024 * 1024,
+			block_size: 16 * 1024,
 			write_rate_limit: None,
 		}
 	}
@@ -145,9 +145,9 @@ impl CompactionProfile {
 	/// Slow HDD compaction profile
 	pub fn hdd() -> CompactionProfile {
 		CompactionProfile {
-			initial_file_size: 192 * 1024 * 1024,
-			file_size_multiplier: 1,
-			write_rate_limit: Some(8 * 1024 * 1024),
+			initial_file_size: 256 * 1024 * 1024,
+			block_size: 64 * 1024,
+			write_rate_limit: Some(16 * 1024 * 1024),
 		}
 	}
 }
@@ -157,8 +157,8 @@ impl CompactionProfile {
 pub struct DatabaseConfig {
 	/// Max number of open files.
 	pub max_open_files: i32,
-	/// Cache sizes (in MiB) for specific columns.
-	pub cache_sizes: HashMap<Option<u32>, usize>,
+	/// Memory budget (in MiB) used for setting block cache size, write buffer size.
+	pub memory_budget: Option<usize>,
 	/// Compaction profile
 	pub compaction: CompactionProfile,
 	/// Set number of columns
@@ -176,17 +176,20 @@ impl DatabaseConfig {
 		config
 	}
 
-	/// Set the column cache size in MiB.
-	pub fn set_cache(&mut self, col: Option<u32>, size: usize) {
-		self.cache_sizes.insert(col, size);
+	pub fn memory_budget(&self) -> usize {
+		self.memory_budget.unwrap_or(DB_DEFAULT_MEMORY_BUDGET_MB) * 1024 * 1024
+	}
+
+	pub fn memory_budget_per_col(&self) -> usize {
+		self.memory_budget() / self.columns.unwrap_or(1) as usize
 	}
 }
 
 impl Default for DatabaseConfig {
 	fn default() -> DatabaseConfig {
 		DatabaseConfig {
-			cache_sizes: HashMap::new(),
 			max_open_files: 512,
+			memory_budget: None,
 			compaction: CompactionProfile::default(),
 			columns: None,
 			wal: true,
@@ -217,27 +220,24 @@ struct DBAndColumns {
 }
 
 // get column family configuration from database config.
-fn col_config(col: u32, config: &DatabaseConfig) -> Options {
-	// default cache size for columns not specified.
-	const DEFAULT_CACHE: usize = 2;
-
+fn col_config(config: &DatabaseConfig, block_opts: &BlockBasedOptions) -> Result<Options> {
 	let mut opts = Options::new();
-	opts.set_compaction_style(DBCompactionStyle::DBUniversalCompaction);
-	opts.set_target_file_size_base(config.compaction.initial_file_size);
-	opts.set_target_file_size_multiplier(config.compaction.file_size_multiplier);
-	opts.set_db_write_buffer_size(DB_WRITE_BUFFER_SIZE);
 
-	let col_opt = config.columns.map(|_| col);
+	opts.set_parsed_options("level_compaction_dynamic_level_bytes=true")?;
 
-	{
-		let cache_size = config.cache_sizes.get(&col_opt).cloned().unwrap_or(DEFAULT_CACHE);
-		let mut block_opts = BlockBasedOptions::new();
-		// all goes to read cache.
-		block_opts.set_cache(Cache::new(cache_size * 1024 * 1024));
-		opts.set_block_based_table_factory(&block_opts);
-	}
+	opts.set_block_based_table_factory(block_opts);
+
+	opts.set_parsed_options(
+		&format!("block_based_table_factory={{{};{}}}",
+				 "cache_index_and_filter_blocks=true",
+				 "pin_l0_filter_and_index_blocks_in_cache=true"))?;
+
+	opts.optimize_level_style_compaction(config.memory_budget_per_col() as i32);
+	opts.set_target_file_size_base(config.compaction.initial_file_size);
 
-	opts
+	opts.set_parsed_options("compression_per_level=")?;
+
+	Ok(opts)
 }
 
 /// Key-Value database.
@@ -246,6 +246,7 @@ pub struct Database {
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
 	read_opts: ReadOptions,
+	block_opts: BlockBasedOptions,
 	path: String,
 	// Dirty values added with `write_buffered`. Cleaned on `flush`.
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
@@ -265,31 +266,35 @@ impl Database {
 	/// Open database file. Creates if it does not exist.
 	pub fn open(config: &DatabaseConfig, path: &str) -> Result<Database> {
 		let mut opts = Options::new();
+
 		if let Some(rate_limit) = config.compaction.write_rate_limit {
 			opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit))?;
 		}
-		opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024))?;
-		opts.set_parsed_options("verify_checksums_in_compaction=0")?;
-		opts.set_parsed_options("keep_log_file_num=1")?;
-		opts.set_max_open_files(config.max_open_files);
-		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
-		opts.set_db_write_buffer_size(DB_WRITE_BUFFER_SIZE);
+		opts.create_if_missing(true);
+		opts.set_max_open_files(config.max_open_files);
+		opts.set_parsed_options("keep_log_file_num=1")?;
+		opts.set_parsed_options("bytes_per_sync=1048576")?;
+		opts.set_db_write_buffer_size(config.memory_budget_per_col() / 2);
+		opts.increase_parallelism(cmp::max(1, ::num_cpus::get() as i32 / 2));
+
+		let mut block_opts = BlockBasedOptions::new();
 
-		opts.set_max_background_flushes(DB_BACKGROUND_FLUSHES);
-		opts.set_max_background_compactions(DB_BACKGROUND_COMPACTIONS);
+		{
+			block_opts.set_block_size(config.compaction.block_size);
+			let cache_size = cmp::max(8, config.memory_budget() / 3);
+			let cache = Cache::new(cache_size);
+			block_opts.set_cache(cache);
+		}
 
-		// compaction settings
-		opts.set_compaction_style(DBCompactionStyle::DBUniversalCompaction);
-		opts.set_target_file_size_base(config.compaction.initial_file_size);
-		opts.set_target_file_size_multiplier(config.compaction.file_size_multiplier);
+		let columns = config.columns.unwrap_or(0) as usize;
 
-		let mut cf_options = Vec::with_capacity(config.columns.unwrap_or(0) as usize);
-		let cfnames: Vec<_> = (0..config.columns.unwrap_or(0)).map(|c| format!("col{}", c)).collect();
+		let mut cf_options = Vec::with_capacity(columns);
+		let cfnames: Vec<_> = (0..columns).map(|c| format!("col{}", c)).collect();
 		let cfnames: Vec<&str> = cfnames.iter().map(|n| n as &str).collect();
 
-		for col in 0 .. config.columns.unwrap_or(0) {
-			cf_options.push(col_config(col, &config));
+		for _ in 0 .. config.columns.unwrap_or(0) {
+			cf_options.push(col_config(&config, &block_opts)?);
 		}
 
 		let mut write_opts = WriteOptions::new();
@@ -348,6 +353,7 @@ impl Database {
 			flushing_lock: Mutex::new((false)),
 			path: path.to_owned(),
 			read_opts: read_opts,
+			block_opts: block_opts,
 		})
 	}
 
@@ -632,7 +638,7 @@ impl Database {
 			Some(DBAndColumns { ref mut db, ref mut cfs }) => {
 				let col = cfs.len() as u32;
 				let name = format!("col{}", col);
-				cfs.push(db.create_cf(&name, &col_config(col, &self.config))?);
+				cfs.push(db.create_cf(&name, &col_config(&self.config, &self.block_opts)?)?);
 				Ok(())
 			},
 			None => Ok(()),
diff --git a/util/migration/src/lib.rs b/util/migration/src/lib.rs
index 7763b7d9a..31c6bac09 100644
--- a/util/migration/src/lib.rs
+++ b/util/migration/src/lib.rs
@@ -264,7 +264,7 @@ impl Manager {
 		trace!(target: "migration", "Expecting database to contain {:?} columns", columns);
 		let mut db_config = DatabaseConfig {
 			max_open_files: 64,
-			cache_sizes: Default::default(),
+			memory_budget: None,
 			compaction: config.compaction_profile,
 			columns: columns,
 			wal: true,
