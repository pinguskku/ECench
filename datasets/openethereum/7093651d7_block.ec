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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
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
-		block.drain().commit(&batch, number, hash, ancient).expect("State DB commit failed.");
+		block.drain().commit(&batch, number, hash, ancient).expect("DB commit failed.");
 
 		let route = self.chain.insert_block(&batch, block_data, receipts);
 		self.tracedb.import(&batch, TraceImportRequest {
@@ -451,7 +452,7 @@ impl Client {
 			retracted: route.retracted.len()
 		});
 		// Final commit to the DB
-		self.db.write(batch).expect("State DB write failed.");
+		self.db.write_buffered(batch).expect("DB write failed.");
 		self.chain.commit();
 
 		self.update_last_hashes(&parent, hash);
@@ -975,7 +976,7 @@ impl BlockChainClient for Client {
 	}
 
 	fn last_hashes(&self) -> LastHashes {
-		self.build_last_hashes(self.chain.best_block_hash())
+		(*self.build_last_hashes(self.chain.best_block_hash())).clone()
 	}
 
 	fn queue_transactions(&self, transactions: Vec<Bytes>) {
@@ -1059,6 +1060,7 @@ impl MiningBlockChainClient for Client {
 				precise_time_ns() - start,
 			);
 		});
+		self.db.flush().expect("DB flush failed.");
 		Ok(h)
 	}
 }
diff --git a/ethcore/src/client/test_client.rs b/ethcore/src/client/test_client.rs
index ae3e18737..7698bf07d 100644
--- a/ethcore/src/client/test_client.rs
+++ b/ethcore/src/client/test_client.rs
@@ -272,7 +272,7 @@ impl MiningBlockChainClient for TestBlockChainClient {
 			false,
 			db,
 			&genesis_header,
-			last_hashes,
+			Arc::new(last_hashes),
 			author,
 			gas_range_target,
 			extra_data
diff --git a/ethcore/src/engines/basic_authority.rs b/ethcore/src/engines/basic_authority.rs
index b7c63cfa3..2545340f1 100644
--- a/ethcore/src/engines/basic_authority.rs
+++ b/ethcore/src/engines/basic_authority.rs
@@ -202,7 +202,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -251,7 +251,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/engines/instant_seal.rs b/ethcore/src/engines/instant_seal.rs
index ae235e04c..85d699241 100644
--- a/ethcore/src/engines/instant_seal.rs
+++ b/ethcore/src/engines/instant_seal.rs
@@ -85,7 +85,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, addr, (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close_and_lock();
diff --git a/ethcore/src/env_info.rs b/ethcore/src/env_info.rs
index e6d15cee6..ff1e9d8a2 100644
--- a/ethcore/src/env_info.rs
+++ b/ethcore/src/env_info.rs
@@ -36,7 +36,7 @@ pub struct EnvInfo {
 	/// The block gas limit.
 	pub gas_limit: U256,
 	/// The last 256 block hashes.
-	pub last_hashes: LastHashes,
+	pub last_hashes: Arc<LastHashes>,
 	/// The gas used.
 	pub gas_used: U256,
 }
@@ -49,7 +49,7 @@ impl Default for EnvInfo {
 			timestamp: 0,
 			difficulty: 0.into(),
 			gas_limit: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 		}
 	}
@@ -64,7 +64,7 @@ impl From<ethjson::vm::Env> for EnvInfo {
 			difficulty: e.difficulty.into(),
 			gas_limit: e.gas_limit.into(),
 			timestamp: e.timestamp.into(),
-			last_hashes: (1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect(),
+			last_hashes: Arc::new((1..cmp::min(number + 1, 257)).map(|i| format!("{}", number - i).as_bytes().sha3()).collect()),
 			gas_used: U256::zero(),
 		}
 	}
diff --git a/ethcore/src/ethereum/ethash.rs b/ethcore/src/ethereum/ethash.rs
index 7b9a52340..477aa2129 100644
--- a/ethcore/src/ethereum/ethash.rs
+++ b/ethcore/src/ethereum/ethash.rs
@@ -355,7 +355,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let b = b.close();
@@ -370,7 +370,7 @@ mod tests {
 		let mut db_result = get_temp_journal_db();
 		let mut db = db_result.take();
 		spec.ensure_db_good(db.as_hashdb_mut()).unwrap();
-		let last_hashes = vec![genesis_header.hash()];
+		let last_hashes = Arc::new(vec![genesis_header.hash()]);
 		let vm_factory = Default::default();
 		let mut b = OpenBlock::new(engine.deref(), &vm_factory, Default::default(), false, db, &genesis_header, last_hashes, Address::zero(), (3141562.into(), 31415620.into()), vec![]).unwrap();
 		let mut uncle = Header::new();
@@ -398,7 +398,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
@@ -410,7 +410,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		});
diff --git a/ethcore/src/externalities.rs b/ethcore/src/externalities.rs
index 25fed0176..2c7ecb4e5 100644
--- a/ethcore/src/externalities.rs
+++ b/ethcore/src/externalities.rs
@@ -324,7 +324,7 @@ mod tests {
 			author: 0.into(),
 			timestamp: 0,
 			difficulty: 0.into(),
-			last_hashes: vec![],
+			last_hashes: Arc::new(vec![]),
 			gas_used: 0.into(),
 			gas_limit: 0.into(),
 		}
@@ -391,7 +391,9 @@ mod tests {
 		{
 			let env_info = &mut setup.env_info;
 			env_info.number = test_env_number;
-			env_info.last_hashes.push(test_hash.clone());
+			let mut last_hashes = (*env_info.last_hashes).clone();
+			last_hashes.push(test_hash.clone());
+			env_info.last_hashes = Arc::new(last_hashes);
 		}
 		let state = setup.state.reference_mut();
 		let mut tracer = NoopTracer;
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index cc2e6d1e6..98cd137ed 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -472,7 +472,7 @@ impl MinerService for Miner {
 
 				// TODO: merge this code with client.rs's fn call somwhow.
 				let header = block.header();
-				let last_hashes = chain.last_hashes();
+				let last_hashes = Arc::new(chain.last_hashes());
 				let env_info = EnvInfo {
 					number: header.number(),
 					author: *header.author(),
diff --git a/ethcore/src/state.rs b/ethcore/src/state.rs
index cf9d4e984..e08b0d8f4 100644
--- a/ethcore/src/state.rs
+++ b/ethcore/src/state.rs
@@ -163,9 +163,7 @@ impl State {
 
 	/// Determine whether an account exists.
 	pub fn exists(&self, a: &Address) -> bool {
-		let db = self.trie_factory.readonly(self.db.as_hashdb(), &self.root).expect(SEC_TRIE_DB_UNWRAP_STR);
-		self.cache.borrow().get(&a).unwrap_or(&None).is_some() ||
-			db.contains(a).unwrap_or_else(|e| { warn!("Potential DB corruption encountered: {}", e); false })
+		self.ensure_cached(a, false, |a| a.is_some())
 	}
 
 	/// Get the balance of account `a`.
@@ -242,7 +240,6 @@ impl State {
 		// TODO uncomment once to_pod() works correctly.
 //		trace!("Applied transaction. Diff:\n{}\n", state_diff::diff_pod(&old, &self.to_pod()));
 		try!(self.commit());
-		self.clear();
 		let receipt = Receipt::new(self.root().clone(), e.cumulative_gas_used, e.logs);
 //		trace!("Transaction receipt: {:?}", receipt);
 		Ok(ApplyOutcome{receipt: receipt, trace: e.trace})
@@ -273,9 +270,12 @@ impl State {
 
 		{
 			let mut trie = trie_factory.from_existing(db, root).unwrap();
-			for (address, ref a) in accounts.iter() {
+			for (address, ref mut a) in accounts.iter_mut() {
 				match **a {
-					Some(ref account) if account.is_dirty() => try!(trie.insert(address, &account.rlp())),
+					Some(ref mut account) if account.is_dirty() => {
+						account.set_clean();
+						try!(trie.insert(address, &account.rlp()))
+					},
 					None => try!(trie.remove(address)),
 					_ => (),
 				}
diff --git a/ethcore/src/tests/helpers.rs b/ethcore/src/tests/helpers.rs
index a0120fdf5..57844f129 100644
--- a/ethcore/src/tests/helpers.rs
+++ b/ethcore/src/tests/helpers.rs
@@ -160,7 +160,7 @@ pub fn generate_dummy_client_with_spec_and_data<F>(get_test_spec: F, block_numbe
 			false,
 			db,
 			&last_header,
-			last_hashes.clone(),
+			Arc::new(last_hashes.clone()),
 			author.clone(),
 			(3141562.into(), 31415620.into()),
 			vec![]
diff --git a/util/Cargo.toml b/util/Cargo.toml
index 57bbf8d45..4246df921 100644
--- a/util/Cargo.toml
+++ b/util/Cargo.toml
@@ -21,8 +21,8 @@ rocksdb = { git = "https://github.com/ethcore/rust-rocksdb" }
 lazy_static = "0.2"
 eth-secp256k1 = { git = "https://github.com/ethcore/rust-secp256k1" }
 rust-crypto = "0.2.34"
-elastic-array = "0.4"
-heapsize = "0.3"
+elastic-array = { git = "https://github.com/ethcore/elastic-array" }
+heapsize = { version = "0.3", features = ["unstable"] }
 itertools = "0.4"
 crossbeam = "0.2"
 slab = "0.2"
diff --git a/util/bigint/src/uint.rs b/util/bigint/src/uint.rs
index 766fa33d3..172e09c70 100644
--- a/util/bigint/src/uint.rs
+++ b/util/bigint/src/uint.rs
@@ -36,10 +36,8 @@
 //! The functions here are designed to be fast.
 //!
 
-#[cfg(all(asm_available, target_arch="x86_64"))]
 use std::mem;
 use std::fmt;
-
 use std::str::{FromStr};
 use std::convert::From;
 use std::hash::Hash;
@@ -647,16 +645,46 @@ macro_rules! construct_uint {
 				(arr[index / 8] >> (((index % 8)) * 8)) as u8
 			}
 
+			#[cfg(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64"))]
+			#[inline]
 			fn to_big_endian(&self, bytes: &mut[u8]) {
-				assert!($n_words * 8 == bytes.len());
+				debug_assert!($n_words * 8 == bytes.len());
 				let &$name(ref arr) = self;
-				for i in 0..bytes.len() {
-					let rev = bytes.len() - 1 - i;
-					let pos = rev / 8;
-					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				unsafe {
+					let mut out: *mut u64 = mem::transmute(bytes.as_mut_ptr());
+					out = out.offset($n_words);
+					for i in 0..$n_words {
+						out = out.offset(-1);
+						*out = arr[i].swap_bytes();
+					}
 				}
 			}
 
+			#[cfg(not(any(
+				target_arch = "arm",
+				target_arch = "mips",
+				target_arch = "powerpc",
+				target_arch = "x86",
+				target_arch = "x86_64",
+				target_arch = "aarch64",
+				target_arch = "powerpc64")))]
+			#[inline]
+			fn to_big_endian(&self, bytes: &mut[u8]) {
+				debug_assert!($n_words * 8 == bytes.len());
+				let &$name(ref arr) = self;
+				for i in 0..bytes.len() {
+ 					let rev = bytes.len() - 1 - i;
+ 					let pos = rev / 8;
+ 					bytes[i] = (arr[pos] >> ((rev % 8) * 8)) as u8;
+				}
+			}
 			#[inline]
 			fn exp10(n: usize) -> Self {
 				match n {
diff --git a/util/src/hash.rs b/util/src/hash.rs
index d43730c7a..62b6dfd8f 100644
--- a/util/src/hash.rs
+++ b/util/src/hash.rs
@@ -20,7 +20,8 @@ use rustc_serialize::hex::FromHex;
 use std::{ops, fmt, cmp};
 use std::cmp::*;
 use std::ops::*;
-use std::hash::{Hash, Hasher};
+use std::hash::{Hash, Hasher, BuildHasherDefault};
+use std::collections::{HashMap, HashSet};
 use std::str::FromStr;
 use math::log2;
 use error::UtilError;
@@ -539,6 +540,38 @@ impl_hash!(H520, 65);
 impl_hash!(H1024, 128);
 impl_hash!(H2048, 256);
 
+// Specialized HashMap and HashSet
+
+/// Hasher that just takes 8 bytes of the provided value.
+pub struct PlainHasher(u64);
+
+impl Default for PlainHasher {
+	#[inline]
+	fn default() -> PlainHasher {
+		PlainHasher(0)
+	}
+}
+
+impl Hasher for PlainHasher {
+	#[inline]
+	fn finish(&self) -> u64 {
+		self.0
+	}
+
+	#[inline]
+	fn write(&mut self, bytes: &[u8]) {
+		debug_assert!(bytes.len() == 32);
+		let mut prefix = [0u8; 8];
+		prefix.clone_from_slice(&bytes[0..8]);
+		self.0 = unsafe { ::std::mem::transmute(prefix) };
+	}
+}
+
+/// Specialized version of HashMap with H256 keys and fast hashing function.
+pub type H256FastMap<T> = HashMap<H256, T, BuildHasherDefault<PlainHasher>>;
+/// Specialized version of HashSet with H256 keys and fast hashing function.
+pub type H256FastSet = HashSet<H256, BuildHasherDefault<PlainHasher>>;
+
 #[cfg(test)]
 mod tests {
 	use hash::*;
diff --git a/util/src/journaldb/overlayrecentdb.rs b/util/src/journaldb/overlayrecentdb.rs
index ca9a0f5ef..97fa5959a 100644
--- a/util/src/journaldb/overlayrecentdb.rs
+++ b/util/src/journaldb/overlayrecentdb.rs
@@ -126,7 +126,7 @@ impl OverlayRecentDB {
 	}
 
 	fn payload(&self, key: &H256) -> Option<Bytes> {
-		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?").map(|v| v.to_vec())
+		self.backing.get(self.column, key).expect("Low-level database error. Some issue with your hard disk?")
 	}
 
 	fn read_overlay(db: &Database, col: Option<u32>) -> JournalOverlay {
@@ -239,9 +239,9 @@ impl JournalDB for OverlayRecentDB {
 			k.append(&now);
 			k.append(&index);
 			k.append(&&PADDING[..]);
-			try!(batch.put(self.column, &k.drain(), r.as_raw()));
+			try!(batch.put_vec(self.column, &k.drain(), r.out()));
 			if journal_overlay.latest_era.map_or(true, |e| now > e) {
-				try!(batch.put(self.column, &LATEST_ERA_KEY, &encode(&now)));
+				try!(batch.put_vec(self.column, &LATEST_ERA_KEY, encode(&now).to_vec()));
 				journal_overlay.latest_era = Some(now);
 			}
 			journal_overlay.journal.entry(now).or_insert_with(Vec::new).push(JournalEntry { id: id.clone(), insertions: inserted_keys, deletions: removed_keys });
@@ -280,7 +280,7 @@ impl JournalDB for OverlayRecentDB {
 				}
 				// apply canon inserts first
 				for (k, v) in canon_insertions {
-					try!(batch.put(self.column, &k, &v));
+					try!(batch.put_vec(self.column, &k, v));
 				}
 				// update the overlay
 				for k in overlay_deletions {
diff --git a/util/src/kvdb.rs b/util/src/kvdb.rs
index a87796324..1b1aa8ead 100644
--- a/util/src/kvdb.rs
+++ b/util/src/kvdb.rs
@@ -16,8 +16,11 @@
 
 //! Key-Value store abstraction with `RocksDB` backend.
 
+use common::*;
+use elastic_array::*;
 use std::default::Default;
-use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBVector, DBIterator,
+use rlp::{UntrustedRlp, RlpType, View, Compressible};
+use rocksdb::{DB, Writable, WriteBatch, WriteOptions, IteratorMode, DBIterator,
 	Options, DBCompactionStyle, BlockBasedOptions, Direction, Cache, Column};
 
 const DB_BACKGROUND_FLUSHES: i32 = 2;
@@ -25,30 +28,89 @@ const DB_BACKGROUND_COMPACTIONS: i32 = 2;
 
 /// Write transaction. Batches a sequence of put/delete operations for efficiency.
 pub struct DBTransaction {
-	batch: WriteBatch,
-	cfs: Vec<Column>,
+	ops: RwLock<Vec<DBOp>>,
+}
+
+enum DBOp {
+	Insert {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	InsertCompressed {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+		value: Bytes,
+	},
+	Delete {
+		col: Option<u32>,
+		key: ElasticArray32<u8>,
+	}
 }
 
 impl DBTransaction {
 	/// Create new transaction.
-	pub fn new(db: &Database) -> DBTransaction {
+	pub fn new(_db: &Database) -> DBTransaction {
 		DBTransaction {
-			batch: WriteBatch::new(),
-			cfs: db.cfs.clone(),
+			ops: RwLock::new(Vec::with_capacity(256)),
 		}
 	}
 
 	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
 	pub fn put(&self, col: Option<u32>, key: &[u8], value: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.put(key, value), |c| self.batch.put_cf(self.cfs[c as usize], key, value))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value.to_vec(),
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	pub fn put_vec(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Insert {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
+	}
+
+	/// Insert a key-value pair in the transaction. Any existing value value will be overwritten upon write.
+	/// Value will be RLP-compressed on  flush
+	pub fn put_compressed(&self, col: Option<u32>, key: &[u8], value: Bytes) -> Result<(), String> {
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::InsertCompressed {
+			col: col,
+			key: ekey,
+			value: value,
+		});
+		Ok(())
 	}
 
 	/// Delete value by key.
 	pub fn delete(&self, col: Option<u32>, key: &[u8]) -> Result<(), String> {
-		col.map_or_else(|| self.batch.delete(key), |c| self.batch.delete_cf(self.cfs[c as usize], key))
+		let mut ekey = ElasticArray32::new();
+		ekey.append_slice(key);
+		self.ops.write().push(DBOp::Delete {
+			col: col,
+			key: ekey,
+		});
+		Ok(())
 	}
 }
 
+struct DBColumnOverlay {
+	insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	compressed_insertions: HashMap<ElasticArray32<u8>, Bytes>,
+	deletions: HashSet<ElasticArray32<u8>>,
+}
+
 /// Compaction profile for the database settings
 #[derive(Clone, Copy)]
 pub struct CompactionProfile {
@@ -118,7 +180,7 @@ impl Default for DatabaseConfig {
 	}
 }
 
-/// Database iterator
+/// Database iterator for flushed data only
 pub struct DatabaseIterator {
 	iter: DBIterator,
 }
@@ -136,6 +198,7 @@ pub struct Database {
 	db: DB,
 	write_opts: WriteOptions,
 	cfs: Vec<Column>,
+	overlay: RwLock<Vec<DBColumnOverlay>>,
 }
 
 impl Database {
@@ -209,7 +272,16 @@ impl Database {
 			},
 			Err(s) => { return Err(s); }
 		};
-		Ok(Database { db: db, write_opts: write_opts, cfs: cfs })
+		Ok(Database {
+			db: db,
+			write_opts: write_opts,
+			overlay: RwLock::new((0..(cfs.len() + 1)).map(|_| DBColumnOverlay {
+				insertions: HashMap::new(),
+				compressed_insertions: HashMap::new(),
+				deletions: HashSet::new(),
+			}).collect()),
+			cfs: cfs,
+		})
 	}
 
 	/// Creates new transaction for this database.
@@ -217,14 +289,107 @@ impl Database {
 		DBTransaction::new(self)
 	}
 
+
+	fn to_overly_column(col: Option<u32>) -> usize {
+		col.map_or(0, |c| (c + 1) as usize)
+	}
+
+	/// Commit transaction to database.
+	pub fn write_buffered(&self, tr: DBTransaction) -> Result<(), String> {
+		let mut overlay = self.overlay.write();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].insertions.insert(key, value);
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].deletions.remove(&key);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.insert(key, value);
+				},
+				DBOp::Delete { col, key } => {
+					let c = Self::to_overly_column(col);
+					overlay[c].insertions.remove(&key);
+					overlay[c].compressed_insertions.remove(&key);
+					overlay[c].deletions.insert(key);
+				},
+			}
+		};
+		Ok(())
+	}
+
+	/// Commit buffered changes to database.
+	pub fn flush(&self) -> Result<(), String> {
+		let batch = WriteBatch::new();
+		let mut overlay = self.overlay.write();
+
+		let mut c = 0;
+		for column in overlay.iter_mut() {
+			let insertions = mem::replace(&mut column.insertions, HashMap::new());
+			let compressed_insertions = mem::replace(&mut column.compressed_insertions, HashMap::new());
+			let deletions = mem::replace(&mut column.deletions, HashSet::new());
+			for d in deletions.into_iter() {
+				if c > 0 {
+					try!(batch.delete_cf(self.cfs[c - 1], &d));
+				} else {
+					try!(batch.delete(&d));
+				}
+			}
+			for (key, value) in insertions.into_iter() {
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &value));
+				} else {
+					try!(batch.put(&key, &value));
+				}
+			}
+			for (key, value) in compressed_insertions.into_iter() {
+				let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+				if c > 0 {
+					try!(batch.put_cf(self.cfs[c - 1], &key, &compressed));
+				} else {
+					try!(batch.put(&key, &compressed));
+				}
+			}
+			c += 1;
+		}
+		self.db.write_opt(batch, &self.write_opts)
+	}
+
+
 	/// Commit transaction to database.
 	pub fn write(&self, tr: DBTransaction) -> Result<(), String> {
-		self.db.write_opt(tr.batch, &self.write_opts)
+		let batch = WriteBatch::new();
+		let ops = mem::replace(&mut *tr.ops.write(), Vec::new());
+		for op in ops {
+			match op {
+				DBOp::Insert { col, key, value } => {
+					try!(col.map_or_else(|| batch.put(&key, &value), |c| batch.put_cf(self.cfs[c as usize], &key, &value)))
+				},
+				DBOp::InsertCompressed { col, key, value } => {
+					let compressed = UntrustedRlp::new(&value).compress(RlpType::Blocks);
+					try!(col.map_or_else(|| batch.put(&key, &compressed), |c| batch.put_cf(self.cfs[c as usize], &key, &compressed)))
+				},
+				DBOp::Delete { col, key } => {
+					try!(col.map_or_else(|| batch.delete(&key), |c| batch.delete_cf(self.cfs[c as usize], &key)))
+				},
+			}
+		}
+		self.db.write_opt(batch, &self.write_opts)
 	}
 
 	/// Get value by key.
-	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<DBVector>, String> {
-		col.map_or_else(|| self.db.get(key), |c| self.db.get_cf(self.cfs[c as usize], key))
+	pub fn get(&self, col: Option<u32>, key: &[u8]) -> Result<Option<Bytes>, String> {
+		let overlay = &self.overlay.read()[Self::to_overly_column(col)];
+		overlay.insertions.get(key).or_else(|| overlay.compressed_insertions.get(key)).map_or_else(||
+			col.map_or_else(
+				|| self.db.get(key).map(|r| r.map(|v| v.to_vec())),
+				|c| self.db.get_cf(self.cfs[c as usize], key).map(|r| r.map(|v| v.to_vec()))),
+			|value| Ok(Some(value.clone())))
 	}
 
 	/// Get value by partial key. Prefix size should match configured prefix size.
diff --git a/util/src/memorydb.rs b/util/src/memorydb.rs
index cc5121bc3..7a3169f7a 100644
--- a/util/src/memorydb.rs
+++ b/util/src/memorydb.rs
@@ -73,7 +73,7 @@ use std::collections::hash_map::Entry;
 /// ```
 #[derive(Default, Clone, PartialEq)]
 pub struct MemoryDB {
-	data: HashMap<H256, (Bytes, i32)>,
+	data: H256FastMap<(Bytes, i32)>,
 	aux: HashMap<Bytes, Bytes>,
 }
 
@@ -81,7 +81,7 @@ impl MemoryDB {
 	/// Create a new instance of the memory DB.
 	pub fn new() -> MemoryDB {
 		MemoryDB {
-			data: HashMap::new(),
+			data: H256FastMap::default(),
 			aux: HashMap::new(),
 		}
 	}
@@ -116,8 +116,8 @@ impl MemoryDB {
 	}
 
 	/// Return the internal map of hashes to data, clearing the current state.
-	pub fn drain(&mut self) -> HashMap<H256, (Bytes, i32)> {
-		mem::replace(&mut self.data, HashMap::new())
+	pub fn drain(&mut self) -> H256FastMap<(Bytes, i32)> {
+		mem::replace(&mut self.data, H256FastMap::default())
 	}
 
 	/// Return the internal map of auxiliary data, clearing the current state.
@@ -144,7 +144,7 @@ impl MemoryDB {
 	pub fn denote(&self, key: &H256, value: Bytes) -> (&[u8], i32) {
 		if self.raw(key) == None {
 			unsafe {
-				let p = &self.data as *const HashMap<H256, (Bytes, i32)> as *mut HashMap<H256, (Bytes, i32)>;
+				let p = &self.data as *const H256FastMap<(Bytes, i32)> as *mut H256FastMap<(Bytes, i32)>;
 				(*p).insert(key.clone(), (value, 0));
 			}
 		}
