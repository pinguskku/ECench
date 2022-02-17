commit 7093651d702c90d2ec1963cc377b81dc037ff898
Author: Arkadiy Paronyan <arkady.paronyan@gmail.com>
Date:   Wed Aug 3 22:03:40 2016 +0200

    More performance optimizations (#1814)
    
    * Buffered DB
    
    * Use identity hash for MemoryDB
    
    * Various tweaks
    
    * Delayed DB compression
    
    * Reduce last_hashes cloning
    
    * Keep state cache
    
    * Updating tests
    
    * Optimized to_big_int
    
    * Fixing build with stable
    
    * Safer code

diff --git a/Cargo.lock b/Cargo.lock
index a9ca1a27f..ddef7cba9 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -73,7 +73,7 @@ dependencies = [
 name = "bigint"
 version = "0.1.0"
 dependencies = [
- "heapsize 0.3.5 (registry+https://github.com/rust-lang/crates.io-index)",
+ "heapsize 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "rustc-serialize 0.3.19 (registry+https://github.com/rust-lang/crates.io-index)",
  "rustc_version 0.1.7 (registry+https://github.com/rust-lang/crates.io-index)",
 ]
@@ -220,7 +220,7 @@ dependencies = [
 [[package]]
 name = "elastic-array"
 version = "0.4.0"
-source = "registry+https://github.com/rust-lang/crates.io-index"
+source = "git+https://github.com/ethcore/elastic-array#9a9bebd6ea291c58e4d6b44dd5dc18368638fefe"
 
 [[package]]
 name = "env_logger"
@@ -270,7 +270,7 @@ dependencies = [
  "ethcore-util 1.3.0",
  "ethjson 0.1.0",
  "ethstore 0.1.0",
- "heapsize 0.3.5 (registry+https://github.com/rust-lang/crates.io-index)",
+ "heapsize 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "hyper 0.9.4 (git+https://github.com/ethcore/hyper)",
  "lazy_static 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -434,11 +434,11 @@ dependencies = [
  "chrono 0.2.22 (registry+https://github.com/rust-lang/crates.io-index)",
  "clippy 0.0.80 (registry+https://github.com/rust-lang/crates.io-index)",
  "crossbeam 0.2.9 (registry+https://github.com/rust-lang/crates.io-index)",
- "elastic-array 0.4.0 (registry+https://github.com/rust-lang/crates.io-index)",
+ "elastic-array 0.4.0 (git+https://github.com/ethcore/elastic-array)",
  "env_logger 0.3.3 (registry+https://github.com/rust-lang/crates.io-index)",
  "eth-secp256k1 0.5.4 (git+https://github.com/ethcore/rust-secp256k1)",
  "ethcore-devtools 1.3.0",
- "heapsize 0.3.5 (registry+https://github.com/rust-lang/crates.io-index)",
+ "heapsize 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "igd 0.5.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "itertools 0.4.13 (registry+https://github.com/rust-lang/crates.io-index)",
  "lazy_static 0.2.1 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -513,7 +513,7 @@ dependencies = [
  "ethcore-ipc-codegen 1.3.0",
  "ethcore-ipc-nano 1.3.0",
  "ethcore-util 1.3.0",
- "heapsize 0.3.5 (registry+https://github.com/rust-lang/crates.io-index)",
+ "heapsize 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "log 0.3.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "parking_lot 0.2.6 (registry+https://github.com/rust-lang/crates.io-index)",
  "rand 0.3.14 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -545,7 +545,7 @@ source = "registry+https://github.com/rust-lang/crates.io-index"
 
 [[package]]
 name = "heapsize"
-version = "0.3.5"
+version = "0.3.6"
 source = "registry+https://github.com/rust-lang/crates.io-index"
 dependencies = [
  "kernel32-sys 0.2.2 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/ethcore/src/account.rs b/ethcore/src/account.rs
index 396e057c0..19e5d6488 100644
--- a/ethcore/src/account.rs
+++ b/ethcore/src/account.rs
@@ -191,6 +191,12 @@ impl Account {
 	pub fn is_dirty(&self) -> bool {
 		self.filth == Filth::Dirty
 	}
+
+	/// Mark account as clean.
+	pub fn set_clean(&mut self) {
+		self.filth = Filth::Clean
+	}
+
 	/// Provide a database to get `code_hash`. Should not be called if it is a contract without code.
 	pub fn cache_code(&mut self, db: &AccountDB) -> bool {
 		// TODO: fill out self.code_cache;
diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index 98927e59f..44fb1676f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -193,7 +193,7 @@ pub struct OpenBlock<'x> {
 	block: ExecutedBlock,
 	engine: &'x Engine,
 	vm_factory: &'x EvmFactory,
-	last_hashes: LastHashes,
+	last_hashes: Arc<LastHashes>,
 }
 
 /// Just like `OpenBlock`, except that we've applied `Engine::on_close_block`, finished up the non-seal header fields,
@@ -204,7 +204,7 @@ pub struct OpenBlock<'x> {
 pub struct ClosedBlock {
 	block: ExecutedBlock,
 	uncle_bytes: Bytes,
-	last_hashes: LastHashes,
+	last_hashes: Arc<LastHashes>,
 	unclosed_state: State,
 }
 
@@ -235,7 +235,7 @@ impl<'x> OpenBlock<'x> {
 		tracing: bool,
 		db: Box<JournalDB>,
 		parent: &Header,
-		last_hashes: LastHashes,
+		last_hashes: Arc<LastHashes>,
 		author: Address,
 		gas_range_target: (U256, U256),
 		extra_data: Bytes,
@@ -316,7 +316,7 @@ impl<'x> OpenBlock<'x> {
 			author: self.block.base.header.author.clone(),
 			timestamp: self.block.base.header.timestamp,
 			difficulty: self.block.base.header.difficulty.clone(),
-			last_hashes: self.last_hashes.clone(),		// TODO: should be a reference.
+			last_hashes: self.last_hashes.clone(),
 			gas_used: self.block.receipts.last().map_or(U256::zero(), |r| r.gas_used),
 			gas_limit: self.block.base.header.gas_limit.clone(),
 		}
@@ -498,7 +498,7 @@ pub fn enact(
 	tracing: bool,
 	db: Box<JournalDB>,
 	parent: &Header,
-	last_hashes: LastHashes,
+	last_hashes: Arc<LastHashes>,
 	vm_factory: &EvmFactory,
 	trie_factory: TrieFactory,
 ) -> Result<LockedBlock, Error> {
@@ -531,7 +531,7 @@ pub fn enact_bytes(
 	tracing: bool,
 	db: Box<JournalDB>,
 	parent: &Header,
-	last_hashes: LastHashes,
+	last_hashes: Arc<LastHashes>,
 	vm_factory: &EvmFactory,
 	trie_factory: TrieFactory,
 ) -> Result<LockedBlock, Error> {
@@ -548,7 +548,7 @@ pub fn enact_verified(
 	tracing: bool,
 	db: Box<JournalDB>,
 	parent: &Header,
-	last_hashes: LastHashes,
+	last_hashes: Arc<LastHashes>,
 	vm_factory: &EvmFactory,
 	trie_factory: TrieFactory,
 ) -> Result<LockedBlock, Error> {
@@ -564,7 +564,7 @@ pub fn enact_and_seal(
 	tracing: bool,
 	db: Box<JournalDB>,
 	parent: &Header,
-	last_hashes: LastHashes,
+	last_hashes: Arc<LastHashes>,
 	vm_factory: &EvmFactory,
 	trie_factory: TrieFactory,
 ) -> Result<SealedBlock, Error> {
@@ -587,7 +587,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
@@ -605,7 +605,8 @@ mod tests {
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
 		let vm_factory = Default::default();
-		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, vec![genesis_header.hash()], Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap()
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
+		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap()
 			.close_and_lock().seal(engine.deref(), vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
 		let orig_db = b.drain();
@@ -613,7 +614,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let e = enact_and_seal(&orig_bytes, engine.deref(), false, db, &genesis_header, vec![genesis_header.hash()], &Default::default(), Default::default()).unwrap();
+		let e = enact_and_seal(&orig_bytes, engine.deref(), false, db, &genesis_header, last_hashes, &Default::default(), Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
@@ -633,7 +634,8 @@ mod tests {
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
 		let vm_factory = Default::default();
-		let mut open_block = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, vec![genesis_header.hash()], Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
+		let mut open_block = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle1_header = Header::new();
 		uncle1_header.extra_data = b"uncle1".to_vec();
 		let mut uncle2_header = Header::new();
@@ -648,7 +650,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let e = enact_and_seal(&orig_bytes, engine.deref(), false, db, &genesis_header, vec![genesis_header.hash()], &Default::default(), Default::default()).unwrap();
+		let e = enact_and_seal(&orig_bytes, engine.deref(), false, db, &genesis_header, last_hashes, &Default::default(), Default::default()).unwrap();
 
 		let bytes = e.rlp_bytes();
 		assert_eq!(bytes, orig_bytes);
diff --git a/ethcore/src/blockchain/blockchain.rs b/ethcore/src/blockchain/blockchain.rs
index 9cc65546e..586fcb575 100644
--- a/ethcore/src/blockchain/blockchain.rs
+++ b/ethcore/src/blockchain/blockchain.rs
@@ -549,15 +549,11 @@ impl BlockChain {
 
 		assert!(self.pending_best_block.read().is_none());
 
-		let block_rlp = UntrustedRlp::new(bytes);
-		let compressed_header = block_rlp.at(0).unwrap().compress(RlpType::Blocks);
-		let compressed_body = UntrustedRlp::new(&Self::block_to_body(bytes)).compress(RlpType::Blocks);
-
 		// store block in db
-		batch.put(DB_COL_HEADERS, &hash, &compressed_header).unwrap();
-		batch.put(DB_COL_BODIES, &hash, &compressed_body).unwrap();
+		batch.put_compressed(DB_COL_HEADERS, &hash, block.header_rlp().as_raw().to_vec()).unwrap();
+		batch.put_compressed(DB_COL_BODIES, &hash, Self::block_to_body(bytes)).unwrap();
 
-		let info = self.block_info(bytes);
+		let info = self.block_info(&header);
 
 		if let BlockLocation::BranchBecomingCanonChain(ref d) = info.location {
 			info!(target: "reorg", "Reorg to {} ({} {} {})",
@@ -582,10 +578,8 @@ impl BlockChain {
 	}
 
 	/// Get inserted block info which is critical to prepare extras updates.
-	fn block_info(&self, block_bytes: &[u8]) -> BlockInfo {
-		let block = BlockView::new(block_bytes);
-		let header = block.header_view();
-		let hash = block.sha3();
+	fn block_info(&self, header: &HeaderView) -> BlockInfo {
+		let hash = header.sha3();
 		let number = header.number();
 		let parent_hash = header.parent_hash();
 		let parent_details = self.block_details(&parent_hash).unwrap_or_else(|| panic!("Invalid parent hash: {:?}", parent_hash));
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 88193d7f8..343eeec82 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -246,13 +246,13 @@ impl Client {
 		}
 	}
 
-	fn build_last_hashes(&self, parent_hash: H256) -> LastHashes {
+	fn build_last_hashes(&self, parent_hash: H256) -> Arc<LastHashes> {
 		{
 			let hashes = self.last_hashes.read();
 			if hashes.front().map_or(false, |h| h == &parent_hash) {
 				let mut res = Vec::from(hashes.clone());
 				res.resize(256, H256::default());
-				return res;
+				return Arc::new(res);
 			}
 		}
 		let mut last_hashes = LastHashes::new();
@@ -268,7 +268,7 @@ impl Client {
 		}
 		let mut cached_hashes = self.last_hashes.write();
 		*cached_hashes = VecDeque::from(last_hashes.clone());
-		last_hashes
+		Arc::new(last_hashes)
 	}
 
 	fn check_and_close_block(&self, block: &PreverifiedBlock) -> Result<LockedBlock, ()> {
@@ -413,6 +413,7 @@ impl Client {
 			}
 		}
 
+		self.db.flush().expect("DB flush failed.");
 		imported
 	}
 
@@ -440,7 +441,7 @@ impl Client {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
