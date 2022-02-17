commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
commit 835cd13c0ef8fc411d06a7414163c4e57d748e82
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Fri Oct 14 14:44:11 2016 +0200

    Database performance tweaks (#2619)

diff --git a/Cargo.lock b/Cargo.lock
index 9550d6ddd..cee712727 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -1406,7 +1406,7 @@ dependencies = [
 [[package]]
 name = "rocksdb"
 version = "0.4.5"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "rocksdb-sys 0.3.0 (git+https://github.com/ethcore/rust-rocksdb)",
@@ -1415,7 +1415,7 @@ dependencies = [
 [[package]]
 name = "rocksdb-sys"
 version = "0.3.0"
-source = "git+https://github.com/ethcore/rust-rocksdb#ffc7c82380fe8569f85ae6743f7f620af2d4a679"
+source = "git+https://github.com/ethcore/rust-rocksdb#64c63ccbe1f62c2e2b39262486f9ba813793af58"
 dependencies = [
  "gcc 0.3.35 (registry+https://github.com/rust-lang/crates.io-index)",
  "libc 0.2.15 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/state_db.rs b/ethcore/src/state_db.rs
index 4358dbb42..01f384570 100644
--- a/ethcore/src/state_db.rs
+++ b/ethcore/src/state_db.rs
@@ -31,8 +31,7 @@ pub const DEFAULT_ACCOUNT_PRESET: usize = 1000000;
 
 pub const ACCOUNT_BLOOM_HASHCOUNT_KEY: &'static [u8] = b"account_hash_count";
 
-const STATE_CACHE_BLOCKS: usize = 8;
-
+const STATE_CACHE_BLOCKS: usize = 12;
 
 /// Shared canonical state cache.
 struct AccountCache {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index df36918dd..92b7e9fbd 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -23,7 +23,7 @@ use std::default::Default;
 use std::path::PathBuf;
 use rlp::{UntrustedRlp, RlpType, View, Compressible};
 use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
-	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
+	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column, ReadOptions};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
 const DB_BACKGROUND_COMPACTIONS: i32 = 2;
@@ -207,6 +207,7 @@ pub struct Database {
 	db: RwLock<Option<DBAndColumns>>,
 	config: DatabaseConfig,
 	write_opts: WriteOptions,
+	read_opts: ReadOptions,
 	overlay: RwLock<Vec<HashMap<ElasticArray32<u8>, KeyState>>>,
 	path: String,
 }
@@ -227,6 +228,7 @@ impl Database {
 			try!(opts.set_parsed_options(&format!("rate_limiter_bytes_per_sec={}", rate_limit)));
 		}
 		try!(opts.set_parsed_options(&format!("max_total_wal_size={}", 64 * 1024 * 1024)));
+		try!(opts.set_parsed_options("verify_checksums_in_compaction=0"));
 		opts.set_max_open_files(config.max_open_files);
 		opts.create_if_missing(true);
 		opts.set_use_fsync(false);
@@ -264,6 +266,8 @@ impl Database {
 		if !config.wal {
 			write_opts.disable_wal(true);
 		}
+		let mut read_opts = ReadOptions::new();
+		read_opts.set_verify_checksums(false);
 
 		let mut cfs: Vec<Column> = Vec::new();
 		let db = match config.columns {
@@ -307,6 +311,7 @@ impl Database {
 			write_opts: write_opts,
 			overlay: RwLock::new((0..(num_cols + 1)).map(|_| HashMap::new()).collect()),
 			path: path.to_owned(),
+			read_opts: read_opts,
 		})
 	}
 
@@ -421,8 +426,8 @@ impl Database {
 					Some(&KeyState::Delete) => Ok(None),
 					None => {
 						col.map_or_else(
-							|| db.get(key).map(|r| r.map(|v| v.to_vec())),
-							|c| db.get_cf(cfs[c as usize], key).map(|r| r.map(|v| v.to_vec())))
+							|| db.get_opt(key, &self.read_opts).map(|r| r.map(|v| v.to_vec())),
+							|c| db.get_cf_opt(cfs[c as usize], key, &self.read_opts).map(|r| r.map(|v| v.to_vec())))
 					},
 				}
 			},
@@ -435,8 +440,8 @@ impl Database {
 	pub fn get_by_prefix(&self, col: Option<u32>, prefix: &[u8]) -> Option<Box<[u8]>> {
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				let mut iter = col.map_or_else(|| db.iterator(IteratorMode::From(prefix, Direction::Forward)),
-					|c| db.iterator_cf(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward)).unwrap());
+				let mut iter = col.map_or_else(|| db.iterator_opt(IteratorMode::From(prefix, Direction::Forward), &self.read_opts),
+					|c| db.iterator_cf_opt(cfs[c as usize], IteratorMode::From(prefix, Direction::Forward), &self.read_opts).unwrap());
 				match iter.next() {
 					// TODO: use prefix_same_as_start read option (not availabele in C API currently)
 					Some((k, v)) => if k[0 .. prefix.len()] == prefix[..] { Some(v) } else { None },
@@ -452,8 +457,8 @@ impl Database {
 		//TODO: iterate over overlay
 		match *self.db.read() {
 			Some(DBAndColumns { ref db, ref cfs }) => {
-				col.map_or_else(|| DatabaseIterator { iter: db.iterator(IteratorMode::Start) },
-					|c| DatabaseIterator { iter: db.iterator_cf(cfs[c as usize], IteratorMode::Start).unwrap() })
+				col.map_or_else(|| DatabaseIterator { iter: db.iterator_opt(IteratorMode::Start, &self.read_opts) },
+					|c| DatabaseIterator { iter: db.iterator_cf_opt(cfs[c as usize], IteratorMode::Start, &self.read_opts).unwrap() })
 			},
 			None => panic!("Not supported yet") //TODO: return an empty iterator or change return type
 		}
