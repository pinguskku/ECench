commit c8076b2f9d9ac45e1a431366eaa5710cedfdcccc
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Sun Feb 21 19:46:29 2016 +0100

    Threading performance optimizations

diff --git a/Cargo.lock b/Cargo.lock
index cf747f3cc..50274857f 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -151,7 +151,6 @@ dependencies = [
 [[package]]
 name = "eth-secp256k1"
 version = "0.5.4"
-source = "git+https://github.com/arkpar/rust-secp256k1.git#45503e1de68d909b1862e3f2bdb9e1cdfdff3f1e"
 dependencies = [
  "arrayvec 0.3.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "gcc 0.3.24 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -223,7 +222,7 @@ dependencies = [
  "crossbeam 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
  "elastic-array 0.4.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "env_logger 0.3.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "eth-secp256k1 0.5.4 (git+https://github.com/arkpar/rust-secp256k1.git)",
+ "eth-secp256k1 0.5.4",
  "ethcore-devtools 0.9.99",
  "heapsize 0.3.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "igd 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/Cargo.toml b/Cargo.toml
index 7fdfc2bee..f28829180 100644
--- a/Cargo.toml
+++ b/Cargo.toml
@@ -30,3 +30,6 @@ travis-nightly = ["ethcore/json-tests", "dev"]
 [[bin]]
 path = "parity/main.rs"
 name = "parity"
+
+[profile.release]
+debug = true
diff --git a/ethcore/src/block_queue.rs b/ethcore/src/block_queue.rs
index c39f158f0..a51a1e900 100644
--- a/ethcore/src/block_queue.rs
+++ b/ethcore/src/block_queue.rs
@@ -63,7 +63,7 @@ pub struct BlockQueue {
 	panic_handler: Arc<PanicHandler>,
 	engine: Arc<Box<Engine>>,
 	more_to_verify: Arc<Condvar>,
-	verification: Arc<Mutex<Verification>>,
+	verification: Arc<Verification>,
 	verifiers: Vec<JoinHandle<()>>,
 	deleting: Arc<AtomicBool>,
 	ready_signal: Arc<QueueSignal>,
@@ -98,12 +98,11 @@ impl QueueSignal {
 	}
 }
 
-#[derive(Default)]
 struct Verification {
-	unverified: VecDeque<UnVerifiedBlock>,
-	verified: VecDeque<PreVerifiedBlock>,
-	verifying: VecDeque<VerifyingBlock>,
-	bad: HashSet<H256>,
+	unverified: Mutex<VecDeque<UnVerifiedBlock>>,
+	verified: Mutex<VecDeque<PreVerifiedBlock>>,
+	verifying: Mutex<VecDeque<VerifyingBlock>>,
+	bad: Mutex<HashSet<H256>>,
 }
 
 const MAX_UNVERIFIED_QUEUE_SIZE: usize = 50000;
@@ -111,7 +110,12 @@ const MAX_UNVERIFIED_QUEUE_SIZE: usize = 50000;
 impl BlockQueue {
 	/// Creates a new queue instance.
 	pub fn new(engine: Arc<Box<Engine>>, message_channel: IoChannel<NetSyncMessage>) -> BlockQueue {
-		let verification = Arc::new(Mutex::new(Verification::default()));
+		let verification = Arc::new(Verification {
+			unverified: Mutex::new(VecDeque::new()),
+			verified: Mutex::new(VecDeque::new()),
+			verifying: Mutex::new(VecDeque::new()),
+			bad: Mutex::new(HashSet::new()),
+		});
 		let more_to_verify = Arc::new(Condvar::new());
 		let ready_signal = Arc::new(QueueSignal { signalled: AtomicBool::new(false), message_channel: message_channel });
 		let deleting = Arc::new(AtomicBool::new(false));
@@ -119,7 +123,7 @@ impl BlockQueue {
 		let panic_handler = PanicHandler::new_in_arc();
 
 		let mut verifiers: Vec<JoinHandle<()>> = Vec::new();
-		let thread_count = max(::num_cpus::get(), 3) - 2;
+		let thread_count = max(::num_cpus::get(), 5) - 0;
 		for i in 0..thread_count {
 			let verification = verification.clone();
 			let engine = engine.clone();
@@ -133,7 +137,8 @@ impl BlockQueue {
 				.name(format!("Verifier #{}", i))
 				.spawn(move || {
 					panic_handler.catch_panic(move || {
-					  BlockQueue::verify(verification, engine, more_to_verify, ready_signal, deleting, empty)
+						lower_thread_priority();
+						BlockQueue::verify(verification, engine, more_to_verify, ready_signal, deleting, empty)
 					}).unwrap()
 				})
 				.expect("Error starting block verification thread")
@@ -152,17 +157,17 @@ impl BlockQueue {
 		}
 	}
 
-	fn verify(verification: Arc<Mutex<Verification>>, engine: Arc<Box<Engine>>, wait: Arc<Condvar>, ready: Arc<QueueSignal>, deleting: Arc<AtomicBool>, empty: Arc<Condvar>) {
+	fn verify(verification: Arc<Verification>, engine: Arc<Box<Engine>>, wait: Arc<Condvar>, ready: Arc<QueueSignal>, deleting: Arc<AtomicBool>, empty: Arc<Condvar>) {
 		while !deleting.load(AtomicOrdering::Acquire) {
 			{
-				let mut lock = verification.lock().unwrap();
+				let mut unverified = verification.unverified.lock().unwrap();
 
-				if lock.unverified.is_empty() && lock.verifying.is_empty() {
+				if unverified.is_empty() && verification.verifying.lock().unwrap().is_empty() {
 					empty.notify_all();
 				}
 
-				while lock.unverified.is_empty() && !deleting.load(AtomicOrdering::Acquire) {
-					lock = wait.wait(lock).unwrap();
+				while unverified.is_empty() && !deleting.load(AtomicOrdering::Acquire) {
+					unverified = wait.wait(unverified).unwrap();
 				}
 
 				if deleting.load(AtomicOrdering::Acquire) {
@@ -171,39 +176,42 @@ impl BlockQueue {
 			}
 
 			let block = {
-				let mut v = verification.lock().unwrap();
-				if v.unverified.is_empty() {
+				let mut unverified = verification.unverified.lock().unwrap();
+				if unverified.is_empty() {
 					continue;
 				}
-				let block = v.unverified.pop_front().unwrap();
-				v.verifying.push_back(VerifyingBlock{ hash: block.header.hash(), block: None });
+				let mut verifying = verification.verifying.lock().unwrap();
+				let block = unverified.pop_front().unwrap();
+				verifying.push_back(VerifyingBlock{ hash: block.header.hash(), block: None });
 				block
 			};
 
 			let block_hash = block.header.hash();
 			match verify_block_unordered(block.header, block.bytes, engine.deref().deref()) {
 				Ok(verified) => {
-					let mut v = verification.lock().unwrap();
-					for e in &mut v.verifying {
+					let mut verifying = verification.verifying.lock().unwrap();
+					for e in verifying.iter_mut() {
 						if e.hash == block_hash {
 							e.block = Some(verified);
 							break;
 						}
 					}
-					if !v.verifying.is_empty() && v.verifying.front().unwrap().hash == block_hash {
+					if !verifying.is_empty() && verifying.front().unwrap().hash == block_hash {
 						// we're next!
-						let mut vref = v.deref_mut();
-						BlockQueue::drain_verifying(&mut vref.verifying, &mut vref.verified, &mut vref.bad);
+						let mut verified = verification.verified.lock().unwrap();
+						let mut bad = verification.bad.lock().unwrap();
+						BlockQueue::drain_verifying(&mut verifying, &mut verified, &mut bad);
 						ready.set();
 					}
 				},
 				Err(err) => {
-					let mut v = verification.lock().unwrap();
+					let mut verifying = verification.verifying.lock().unwrap();
+					let mut verified = verification.verified.lock().unwrap();
+					let mut bad = verification.bad.lock().unwrap();
 					warn!(target: "client", "Stage 2 block verification failed for {}\nError: {:?}", block_hash, err);
-					v.bad.insert(block_hash.clone());
-					v.verifying.retain(|e| e.hash != block_hash);
-					let mut vref = v.deref_mut();
-					BlockQueue::drain_verifying(&mut vref.verifying, &mut vref.verified, &mut vref.bad);
+					bad.insert(block_hash.clone());
+					verifying.retain(|e| e.hash != block_hash);
+					BlockQueue::drain_verifying(&mut verifying, &mut verified, &mut bad);
 					ready.set();
 				}
 			}
@@ -223,19 +231,21 @@ impl BlockQueue {
 	}
 
 	/// Clear the queue and stop verification activity.
-	pub fn clear(&mut self) {
-		let mut verification = self.verification.lock().unwrap();
-		verification.unverified.clear();
-		verification.verifying.clear();
-		verification.verified.clear();
+	pub fn clear(&self) {
+		let mut unverified = self.verification.unverified.lock().unwrap();
+		let mut verifying = self.verification.verifying.lock().unwrap();
+		let mut verified = self.verification.verified.lock().unwrap();
+		unverified.clear();
+		verifying.clear();
+		verified.clear();
 		self.processing.write().unwrap().clear();
 	}
 
-	/// Wait for queue to be empty
-	pub fn flush(&mut self) {
-		let mut verification = self.verification.lock().unwrap();
-		while !verification.unverified.is_empty() || !verification.verifying.is_empty() {
-			verification = self.empty.wait(verification).unwrap();
+	/// Wait for unverified queue to be empty
+	pub fn flush(&self) {
+		let mut unverified = self.verification.unverified.lock().unwrap();
+		while !unverified.is_empty() || !self.verification.verifying.lock().unwrap().is_empty() {
+			unverified = self.empty.wait(unverified).unwrap();
 		}
 	}
 
@@ -244,27 +254,29 @@ impl BlockQueue {
 		if self.processing.read().unwrap().contains(&hash) {
 			return BlockStatus::Queued;
 		}
-		if self.verification.lock().unwrap().bad.contains(&hash) {
+		if self.verification.bad.lock().unwrap().contains(&hash) {
 			return BlockStatus::Bad;
 		}
 		BlockStatus::Unknown
 	}
 
 	/// Add a block to the queue.
-	pub fn import_block(&mut self, bytes: Bytes) -> ImportResult {
+	pub fn import_block(&self, bytes: Bytes) -> ImportResult {
 		let header = BlockView::new(&bytes).header();
 		let h = header.hash();
-		if self.processing.read().unwrap().contains(&h) {
-			return Err(ImportError::AlreadyQueued);
-		}
 		{
-			let mut verification = self.verification.lock().unwrap();
-			if verification.bad.contains(&h) {
+			if self.processing.read().unwrap().contains(&h) {
+				return Err(ImportError::AlreadyQueued);
+			}
+			}
+		{
+			let mut bad = self.verification.bad.lock().unwrap();
+			if bad.contains(&h) {
 				return Err(ImportError::Bad(None));
 			}
 
-			if verification.bad.contains(&header.parent_hash) {
-				verification.bad.insert(h.clone());
+			if bad.contains(&header.parent_hash) {
+				bad.insert(h.clone());
 				return Err(ImportError::Bad(None));
 			}
 		}
@@ -272,39 +284,40 @@ impl BlockQueue {
 		match verify_block_basic(&header, &bytes, self.engine.deref().deref()) {
 			Ok(()) => {
 				self.processing.write().unwrap().insert(h.clone());
-				self.verification.lock().unwrap().unverified.push_back(UnVerifiedBlock { header: header, bytes: bytes });
+				self.verification.unverified.lock().unwrap().push_back(UnVerifiedBlock { header: header, bytes: bytes });
 				self.more_to_verify.notify_all();
 				Ok(h)
 			},
 			Err(err) => {
 				warn!(target: "client", "Stage 1 block verification failed for {}\nError: {:?}", BlockView::new(&bytes).header_view().sha3(), err);
-				self.verification.lock().unwrap().bad.insert(h.clone());
+				self.verification.bad.lock().unwrap().insert(h.clone());
 				Err(From::from(err))
 			}
 		}
 	}
 
 	/// Mark given block and all its children as bad. Stops verification.
-	pub fn mark_as_bad(&mut self, hash: &H256) {
-		let mut verification_lock = self.verification.lock().unwrap();
-		let mut verification = verification_lock.deref_mut();
-		verification.bad.insert(hash.clone());
+	pub fn mark_as_bad(&self, hash: &H256) {
+		let mut verified_lock = self.verification.verified.lock().unwrap();
+		let mut verified = verified_lock.deref_mut();
+		let mut bad = self.verification.bad.lock().unwrap();
+		bad.insert(hash.clone());
 		self.processing.write().unwrap().remove(&hash);
 		let mut new_verified = VecDeque::new();
-		for block in verification.verified.drain(..) {
-			if verification.bad.contains(&block.header.parent_hash) {
-				verification.bad.insert(block.header.hash());
+		for block in verified.drain(..) {
+			if bad.contains(&block.header.parent_hash) {
+				bad.insert(block.header.hash());
 				self.processing.write().unwrap().remove(&block.header.hash());
 			}
 			else {
 				new_verified.push_back(block);
 			}
 		}
-		verification.verified = new_verified;
+		*verified = new_verified;
 	}
 
 	/// Mark given block as processed
-	pub fn mark_as_good(&mut self, hashes: &[H256]) {
+	pub fn mark_as_good(&self, hashes: &[H256]) {
 		let mut processing = self.processing.write().unwrap();
 		for h in hashes {
 			processing.remove(&h);
@@ -312,16 +325,16 @@ impl BlockQueue {
 	}
 
 	/// Removes up to `max` verified blocks from the queue
-	pub fn drain(&mut self, max: usize) -> Vec<PreVerifiedBlock> {
-		let mut verification = self.verification.lock().unwrap();
-		let count = min(max, verification.verified.len());
+	pub fn drain(&self, max: usize) -> Vec<PreVerifiedBlock> {
+		let mut verified = self.verification.verified.lock().unwrap();
+		let count = min(max, verified.len());
 		let mut result = Vec::with_capacity(count);
 		for _ in 0..count {
-			let block = verification.verified.pop_front().unwrap();
+			let block = verified.pop_front().unwrap();
 			result.push(block);
 		}
 		self.ready_signal.reset();
-		if !verification.verified.is_empty() {
+		if !verified.is_empty() {
 			self.ready_signal.set();
 		}
 		result
@@ -329,11 +342,10 @@ impl BlockQueue {
 
 	/// Get queue status.
 	pub fn queue_info(&self) -> BlockQueueInfo {
-		let verification = self.verification.lock().unwrap();
 		BlockQueueInfo {
-			verified_queue_size: verification.verified.len(),
-			unverified_queue_size: verification.unverified.len(),
-			verifying_queue_size: verification.verifying.len(),
+			unverified_queue_size: self.verification.unverified.lock().unwrap().len(),
+			verifying_queue_size: self.verification.verifying.lock().unwrap().len(),
+			verified_queue_size: self.verification.verified.lock().unwrap().len(),
 		}
 	}
 }
diff --git a/ethcore/src/client.rs b/ethcore/src/client.rs
index c3ec4b4d0..0c8580117 100644
--- a/ethcore/src/client.rs
+++ b/ethcore/src/client.rs
@@ -172,7 +172,7 @@ pub struct Client {
 	chain: Arc<RwLock<BlockChain>>,
 	engine: Arc<Box<Engine>>,
 	state_db: Mutex<JournalDB>,
-	block_queue: RwLock<BlockQueue>,
+	block_queue: BlockQueue,
 	report: RwLock<ClientReport>,
 	import_lock: Mutex<()>,
 	panic_handler: Arc<PanicHandler>,
@@ -231,7 +231,7 @@ impl Client {
 			chain: chain,
 			engine: engine,
 			state_db: Mutex::new(state_db),
-			block_queue: RwLock::new(block_queue),
+			block_queue: block_queue,
 			report: RwLock::new(Default::default()),
 			import_lock: Mutex::new(()),
 			panic_handler: panic_handler
@@ -240,7 +240,7 @@ impl Client {
 
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
-		self.block_queue.write().unwrap().flush();
+		self.block_queue.flush();
 	}
 
 	/// This is triggered by a message coming from a block queue when the block is ready for insertion
@@ -248,11 +248,11 @@ impl Client {
 		let mut ret = 0;
 		let mut bad = HashSet::new();
 		let _import_lock = self.import_lock.lock();
-		let blocks = self.block_queue.write().unwrap().drain(128);
+		let blocks = self.block_queue.drain(128);
 		let mut good_blocks = Vec::with_capacity(128);
 		for block in blocks {
 			if bad.contains(&block.header.parent_hash) {
-				self.block_queue.write().unwrap().mark_as_bad(&block.header.hash());
+				self.block_queue.mark_as_bad(&block.header.hash());
 				bad.insert(block.header.hash());
 				continue;
 			}
@@ -260,7 +260,7 @@ impl Client {
 			let header = &block.header;
 			if let Err(e) = verify_block_family(&header, &block.bytes, self.engine.deref().deref(), self.chain.read().unwrap().deref()) {
 				warn!(target: "client", "Stage 3 block verification failed for #{} ({})\nError: {:?}", header.number(), header.hash(), e);
-				self.block_queue.write().unwrap().mark_as_bad(&header.hash());
+				self.block_queue.mark_as_bad(&header.hash());
 				bad.insert(block.header.hash());
 				break;
 			};
@@ -268,7 +268,7 @@ impl Client {
 				Some(p) => p,
 				None => {
 					warn!(target: "client", "Block import failed for #{} ({}): Parent not found ({}) ", header.number(), header.hash(), header.parent_hash);
-					self.block_queue.write().unwrap().mark_as_bad(&header.hash());
+					self.block_queue.mark_as_bad(&header.hash());
 					bad.insert(block.header.hash());
 					break;
 				},
@@ -292,13 +292,13 @@ impl Client {
 				Err(e) => {
 					warn!(target: "client", "Block import failed for #{} ({})\nError: {:?}", header.number(), header.hash(), e);
 					bad.insert(block.header.hash());
-					self.block_queue.write().unwrap().mark_as_bad(&header.hash());
+					self.block_queue.mark_as_bad(&header.hash());
 					break;
 				}
 			};
 			if let Err(e) = verify_block_final(&header, result.block().header()) {
 				warn!(target: "client", "Stage 4 block verification failed for #{} ({})\nError: {:?}", header.number(), header.hash(), e);
-				self.block_queue.write().unwrap().mark_as_bad(&header.hash());
+				self.block_queue.mark_as_bad(&header.hash());
 				break;
 			}
 
@@ -317,8 +317,8 @@ impl Client {
 			trace!(target: "client", "Imported #{} ({})", header.number(), header.hash());
 			ret += 1;
 		}
-		self.block_queue.write().unwrap().mark_as_good(&good_blocks);
-		if !good_blocks.is_empty() && self.block_queue.read().unwrap().queue_info().is_empty() {
+		self.block_queue.mark_as_good(&good_blocks);
+		if !good_blocks.is_empty() && self.block_queue.queue_info().is_empty() {
 			io.send(NetworkIoMessage::User(SyncMessage::BlockVerified)).unwrap();
 		}
 		ret
@@ -389,7 +389,7 @@ impl BlockChainClient for Client {
 		let chain = self.chain.read().unwrap();
 		match Self::block_hash(&chain, id) {
 			Some(ref hash) if chain.is_known(hash) => BlockStatus::InChain,
-			Some(hash) => self.block_queue.read().unwrap().block_status(&hash),
+			Some(hash) => self.block_queue.block_status(&hash),
 			None => BlockStatus::Unknown
 		}
 	}
@@ -434,15 +434,15 @@ impl BlockChainClient for Client {
 		if self.block_status(BlockId::Hash(header.parent_hash)) == BlockStatus::Unknown {
 			return Err(ImportError::UnknownParent);
 		}
-		self.block_queue.write().unwrap().import_block(bytes)
+		self.block_queue.import_block(bytes)
 	}
 
 	fn queue_info(&self) -> BlockQueueInfo {
-		self.block_queue.read().unwrap().queue_info()
+		self.block_queue.queue_info()
 	}
 
 	fn clear_queue(&self) {
-		self.block_queue.write().unwrap().clear();
+		self.block_queue.clear();
 	}
 
 	fn chain_info(&self) -> BlockChainInfo {
diff --git a/ethcore/src/verification.rs b/ethcore/src/verification.rs
index c7d5e265f..fa9467e95 100644
--- a/ethcore/src/verification.rs
+++ b/ethcore/src/verification.rs
@@ -57,18 +57,12 @@ pub fn verify_block_basic(header: &Header, bytes: &[u8], engine: &Engine) -> Res
 /// Still operates on a individual block
 /// Returns a PreVerifiedBlock structure populated with transactions
 pub fn verify_block_unordered(header: Header, bytes: Bytes, engine: &Engine) -> Result<PreVerifiedBlock, Error> {
-	try!(engine.verify_block_unordered(&header, Some(&bytes)));
-	for u in Rlp::new(&bytes).at(2).iter().map(|rlp| rlp.as_val::<Header>()) {
-		try!(engine.verify_block_unordered(&u, None));
-	}
 	// Verify transactions. 
 	let mut transactions = Vec::new();
-	{
-		let v = BlockView::new(&bytes);
-		for t in v.transactions() {
-			try!(engine.verify_transaction(&t, &header));
-			transactions.push(t);
-		}
+	let v = BlockView::new(&bytes);
+	for t in v.transactions() {
+		try!(engine.verify_transaction(&t, &header));
+		transactions.push(t);
 	}
 	Ok(PreVerifiedBlock {
 		header: header,
diff --git a/util/sha3/build.rs b/util/sha3/build.rs
index bbe16d720..9eb36fdb9 100644
--- a/util/sha3/build.rs
+++ b/util/sha3/build.rs
@@ -21,6 +21,6 @@
 extern crate gcc;
 
 fn main() {
-    gcc::compile_library("libtinykeccak.a", &["src/tinykeccak.c"]);
+	gcc::Config::new().file("src/tinykeccak.c").flag("-O3").compile("libtinykeccak.a");
 }
 
diff --git a/util/src/lib.rs b/util/src/lib.rs
index 2b7438cf3..5c8bd4fb0 100644
--- a/util/src/lib.rs
+++ b/util/src/lib.rs
@@ -143,6 +143,7 @@ pub mod network;
 pub mod log;
 pub mod panics;
 pub mod keys;
+mod thread;
 
 pub use common::*;
 pub use misc::*;
@@ -163,4 +164,5 @@ pub use semantic_version::*;
 pub use network::*;
 pub use io::*;
 pub use log::*;
+pub use thread::*;
 
diff --git a/util/src/thread.rs b/util/src/thread.rs
new file mode 100644
index 000000000..b86ca3e86
--- /dev/null
+++ b/util/src/thread.rs
@@ -0,0 +1,43 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! Thread management helpers
+
+use libc::{c_int, pthread_self, pthread_t};
+
+#[repr(C)]
+struct sched_param {
+    priority: c_int,
+    padding: c_int,
+}
+
+extern {
+	fn setpriority(which: c_int, who: c_int, prio: c_int) -> c_int;
+	fn pthread_setschedparam(thread: pthread_t, policy: c_int, param: *const sched_param) -> c_int;
+}
+const PRIO_DARWIN_THREAD: c_int = 3;
+const PRIO_DARWIN_BG: c_int = 0x1000;
+const SCHED_RR: c_int = 2;
+
+/// Lower thread priority and put it into background mode
+#[cfg(target_os="macos")]
+pub fn lower_thread_priority() {
+	let sp = sched_param { priority: 0, padding: 0 };
+	if unsafe { pthread_setschedparam(pthread_self(), SCHED_RR, &sp) } == -1 {
+		trace!("Could not decrease thread piority");
+	}
+	//unsafe { setpriority(PRIO_DARWIN_THREAD, 0, PRIO_DARWIN_BG); }
+}
commit c8076b2f9d9ac45e1a431366eaa5710cedfdcccc
Author: arkpar <arkady.paronyan@gmail.com>
Date:   Sun Feb 21 19:46:29 2016 +0100

    Threading performance optimizations

diff --git a/Cargo.lock b/Cargo.lock
index cf747f3cc..50274857f 100644
--- a/Cargo.lock
+++ b/Cargo.lock
@@ -151,7 +151,6 @@ dependencies = [
 [[package]]
 name = "eth-secp256k1"
 version = "0.5.4"
-source = "git+https://github.com/arkpar/rust-secp256k1.git#45503e1de68d909b1862e3f2bdb9e1cdfdff3f1e"
 dependencies = [
  "arrayvec 0.3.15 (registry+https://github.com/rust-lang/crates.io-index)",
  "gcc 0.3.24 (registry+https://github.com/rust-lang/crates.io-index)",
@@ -223,7 +222,7 @@ dependencies = [
  "crossbeam 0.2.8 (registry+https://github.com/rust-lang/crates.io-index)",
  "elastic-array 0.4.0 (registry+https://github.com/rust-lang/crates.io-index)",
  "env_logger 0.3.2 (registry+https://github.com/rust-lang/crates.io-index)",
- "eth-secp256k1 0.5.4 (git+https://github.com/arkpar/rust-secp256k1.git)",
+ "eth-secp256k1 0.5.4",
  "ethcore-devtools 0.9.99",
  "heapsize 0.3.2 (registry+https://github.com/rust-lang/crates.io-index)",
  "igd 0.4.2 (registry+https://github.com/rust-lang/crates.io-index)",
diff --git a/Cargo.toml b/Cargo.toml
index 7fdfc2bee..f28829180 100644
--- a/Cargo.toml
+++ b/Cargo.toml
@@ -30,3 +30,6 @@ travis-nightly = ["ethcore/json-tests", "dev"]
 [[bin]]
 path = "parity/main.rs"
 name = "parity"
+
+[profile.release]
+debug = true
diff --git a/ethcore/src/block_queue.rs b/ethcore/src/block_queue.rs
index c39f158f0..a51a1e900 100644
--- a/ethcore/src/block_queue.rs
+++ b/ethcore/src/block_queue.rs
@@ -63,7 +63,7 @@ pub struct BlockQueue {
 	panic_handler: Arc<PanicHandler>,
 	engine: Arc<Box<Engine>>,
 	more_to_verify: Arc<Condvar>,
-	verification: Arc<Mutex<Verification>>,
+	verification: Arc<Verification>,
 	verifiers: Vec<JoinHandle<()>>,
 	deleting: Arc<AtomicBool>,
 	ready_signal: Arc<QueueSignal>,
@@ -98,12 +98,11 @@ impl QueueSignal {
 	}
 }
 
-#[derive(Default)]
 struct Verification {
-	unverified: VecDeque<UnVerifiedBlock>,
-	verified: VecDeque<PreVerifiedBlock>,
-	verifying: VecDeque<VerifyingBlock>,
-	bad: HashSet<H256>,
+	unverified: Mutex<VecDeque<UnVerifiedBlock>>,
+	verified: Mutex<VecDeque<PreVerifiedBlock>>,
+	verifying: Mutex<VecDeque<VerifyingBlock>>,
+	bad: Mutex<HashSet<H256>>,
 }
 
 const MAX_UNVERIFIED_QUEUE_SIZE: usize = 50000;
@@ -111,7 +110,12 @@ const MAX_UNVERIFIED_QUEUE_SIZE: usize = 50000;
 impl BlockQueue {
 	/// Creates a new queue instance.
 	pub fn new(engine: Arc<Box<Engine>>, message_channel: IoChannel<NetSyncMessage>) -> BlockQueue {
-		let verification = Arc::new(Mutex::new(Verification::default()));
+		let verification = Arc::new(Verification {
+			unverified: Mutex::new(VecDeque::new()),
+			verified: Mutex::new(VecDeque::new()),
+			verifying: Mutex::new(VecDeque::new()),
+			bad: Mutex::new(HashSet::new()),
+		});
 		let more_to_verify = Arc::new(Condvar::new());
 		let ready_signal = Arc::new(QueueSignal { signalled: AtomicBool::new(false), message_channel: message_channel });
 		let deleting = Arc::new(AtomicBool::new(false));
@@ -119,7 +123,7 @@ impl BlockQueue {
 		let panic_handler = PanicHandler::new_in_arc();
 
 		let mut verifiers: Vec<JoinHandle<()>> = Vec::new();
-		let thread_count = max(::num_cpus::get(), 3) - 2;
+		let thread_count = max(::num_cpus::get(), 5) - 0;
 		for i in 0..thread_count {
 			let verification = verification.clone();
 			let engine = engine.clone();
@@ -133,7 +137,8 @@ impl BlockQueue {
 				.name(format!("Verifier #{}", i))
 				.spawn(move || {
 					panic_handler.catch_panic(move || {
-					  BlockQueue::verify(verification, engine, more_to_verify, ready_signal, deleting, empty)
+						lower_thread_priority();
+						BlockQueue::verify(verification, engine, more_to_verify, ready_signal, deleting, empty)
 					}).unwrap()
 				})
 				.expect("Error starting block verification thread")
@@ -152,17 +157,17 @@ impl BlockQueue {
 		}
 	}
 
-	fn verify(verification: Arc<Mutex<Verification>>, engine: Arc<Box<Engine>>, wait: Arc<Condvar>, ready: Arc<QueueSignal>, deleting: Arc<AtomicBool>, empty: Arc<Condvar>) {
+	fn verify(verification: Arc<Verification>, engine: Arc<Box<Engine>>, wait: Arc<Condvar>, ready: Arc<QueueSignal>, deleting: Arc<AtomicBool>, empty: Arc<Condvar>) {
 		while !deleting.load(AtomicOrdering::Acquire) {
 			{
-				let mut lock = verification.lock().unwrap();
+				let mut unverified = verification.unverified.lock().unwrap();
 
-				if lock.unverified.is_empty() && lock.verifying.is_empty() {
+				if unverified.is_empty() && verification.verifying.lock().unwrap().is_empty() {
 					empty.notify_all();
 				}
 
-				while lock.unverified.is_empty() && !deleting.load(AtomicOrdering::Acquire) {
-					lock = wait.wait(lock).unwrap();
+				while unverified.is_empty() && !deleting.load(AtomicOrdering::Acquire) {
+					unverified = wait.wait(unverified).unwrap();
 				}
 
 				if deleting.load(AtomicOrdering::Acquire) {
@@ -171,39 +176,42 @@ impl BlockQueue {
 			}
 
 			let block = {
-				let mut v = verification.lock().unwrap();
-				if v.unverified.is_empty() {
+				let mut unverified = verification.unverified.lock().unwrap();
+				if unverified.is_empty() {
 					continue;
 				}
-				let block = v.unverified.pop_front().unwrap();
-				v.verifying.push_back(VerifyingBlock{ hash: block.header.hash(), block: None });
+				let mut verifying = verification.verifying.lock().unwrap();
+				let block = unverified.pop_front().unwrap();
+				verifying.push_back(VerifyingBlock{ hash: block.header.hash(), block: None });
 				block
 			};
 
 			let block_hash = block.header.hash();
 			match verify_block_unordered(block.header, block.bytes, engine.deref().deref()) {
 				Ok(verified) => {
-					let mut v = verification.lock().unwrap();
-					for e in &mut v.verifying {
+					let mut verifying = verification.verifying.lock().unwrap();
+					for e in verifying.iter_mut() {
 						if e.hash == block_hash {
 							e.block = Some(verified);
 							break;
 						}
 					}
-					if !v.verifying.is_empty() && v.verifying.front().unwrap().hash == block_hash {
+					if !verifying.is_empty() && verifying.front().unwrap().hash == block_hash {
 						// we're next!
-						let mut vref = v.deref_mut();
-						BlockQueue::drain_verifying(&mut vref.verifying, &mut vref.verified, &mut vref.bad);
+						let mut verified = verification.verified.lock().unwrap();
+						let mut bad = verification.bad.lock().unwrap();
+						BlockQueue::drain_verifying(&mut verifying, &mut verified, &mut bad);
 						ready.set();
 					}
 				},
 				Err(err) => {
-					let mut v = verification.lock().unwrap();
+					let mut verifying = verification.verifying.lock().unwrap();
+					let mut verified = verification.verified.lock().unwrap();
+					let mut bad = verification.bad.lock().unwrap();
 					warn!(target: "client", "Stage 2 block verification failed for {}\nError: {:?}", block_hash, err);
-					v.bad.insert(block_hash.clone());
-					v.verifying.retain(|e| e.hash != block_hash);
-					let mut vref = v.deref_mut();
-					BlockQueue::drain_verifying(&mut vref.verifying, &mut vref.verified, &mut vref.bad);
+					bad.insert(block_hash.clone());
+					verifying.retain(|e| e.hash != block_hash);
+					BlockQueue::drain_verifying(&mut verifying, &mut verified, &mut bad);
 					ready.set();
 				}
 			}
@@ -223,19 +231,21 @@ impl BlockQueue {
 	}
 
 	/// Clear the queue and stop verification activity.
-	pub fn clear(&mut self) {
-		let mut verification = self.verification.lock().unwrap();
-		verification.unverified.clear();
-		verification.verifying.clear();
-		verification.verified.clear();
+	pub fn clear(&self) {
+		let mut unverified = self.verification.unverified.lock().unwrap();
+		let mut verifying = self.verification.verifying.lock().unwrap();
+		let mut verified = self.verification.verified.lock().unwrap();
+		unverified.clear();
+		verifying.clear();
+		verified.clear();
 		self.processing.write().unwrap().clear();
 	}
 
-	/// Wait for queue to be empty
-	pub fn flush(&mut self) {
-		let mut verification = self.verification.lock().unwrap();
-		while !verification.unverified.is_empty() || !verification.verifying.is_empty() {
-			verification = self.empty.wait(verification).unwrap();
+	/// Wait for unverified queue to be empty
+	pub fn flush(&self) {
+		let mut unverified = self.verification.unverified.lock().unwrap();
+		while !unverified.is_empty() || !self.verification.verifying.lock().unwrap().is_empty() {
+			unverified = self.empty.wait(unverified).unwrap();
 		}
 	}
 
@@ -244,27 +254,29 @@ impl BlockQueue {
 		if self.processing.read().unwrap().contains(&hash) {
 			return BlockStatus::Queued;
 		}
-		if self.verification.lock().unwrap().bad.contains(&hash) {
+		if self.verification.bad.lock().unwrap().contains(&hash) {
 			return BlockStatus::Bad;
 		}
 		BlockStatus::Unknown
 	}
 
 	/// Add a block to the queue.
-	pub fn import_block(&mut self, bytes: Bytes) -> ImportResult {
+	pub fn import_block(&self, bytes: Bytes) -> ImportResult {
 		let header = BlockView::new(&bytes).header();
 		let h = header.hash();
-		if self.processing.read().unwrap().contains(&h) {
-			return Err(ImportError::AlreadyQueued);
-		}
 		{
-			let mut verification = self.verification.lock().unwrap();
-			if verification.bad.contains(&h) {
+			if self.processing.read().unwrap().contains(&h) {
+				return Err(ImportError::AlreadyQueued);
+			}
+			}
+		{
+			let mut bad = self.verification.bad.lock().unwrap();
+			if bad.contains(&h) {
 				return Err(ImportError::Bad(None));
 			}
 
-			if verification.bad.contains(&header.parent_hash) {
-				verification.bad.insert(h.clone());
+			if bad.contains(&header.parent_hash) {
+				bad.insert(h.clone());
 				return Err(ImportError::Bad(None));
 			}
 		}
@@ -272,39 +284,40 @@ impl BlockQueue {
 		match verify_block_basic(&header, &bytes, self.engine.deref().deref()) {
 			Ok(()) => {
 				self.processing.write().unwrap().insert(h.clone());
-				self.verification.lock().unwrap().unverified.push_back(UnVerifiedBlock { header: header, bytes: bytes });
+				self.verification.unverified.lock().unwrap().push_back(UnVerifiedBlock { header: header, bytes: bytes });
 				self.more_to_verify.notify_all();
 				Ok(h)
 			},
 			Err(err) => {
 				warn!(target: "client", "Stage 1 block verification failed for {}\nError: {:?}", BlockView::new(&bytes).header_view().sha3(), err);
-				self.verification.lock().unwrap().bad.insert(h.clone());
+				self.verification.bad.lock().unwrap().insert(h.clone());
 				Err(From::from(err))
 			}
 		}
 	}
 
 	/// Mark given block and all its children as bad. Stops verification.
-	pub fn mark_as_bad(&mut self, hash: &H256) {
-		let mut verification_lock = self.verification.lock().unwrap();
-		let mut verification = verification_lock.deref_mut();
-		verification.bad.insert(hash.clone());
+	pub fn mark_as_bad(&self, hash: &H256) {
+		let mut verified_lock = self.verification.verified.lock().unwrap();
+		let mut verified = verified_lock.deref_mut();
+		let mut bad = self.verification.bad.lock().unwrap();
+		bad.insert(hash.clone());
 		self.processing.write().unwrap().remove(&hash);
 		let mut new_verified = VecDeque::new();
-		for block in verification.verified.drain(..) {
-			if verification.bad.contains(&block.header.parent_hash) {
-				verification.bad.insert(block.header.hash());
+		for block in verified.drain(..) {
+			if bad.contains(&block.header.parent_hash) {
+				bad.insert(block.header.hash());
 				self.processing.write().unwrap().remove(&block.header.hash());
 			}
 			else {
 				new_verified.push_back(block);
 			}
 		}
-		verification.verified = new_verified;
+		*verified = new_verified;
 	}
 
 	/// Mark given block as processed
-	pub fn mark_as_good(&mut self, hashes: &[H256]) {
+	pub fn mark_as_good(&self, hashes: &[H256]) {
 		let mut processing = self.processing.write().unwrap();
 		for h in hashes {
 			processing.remove(&h);
@@ -312,16 +325,16 @@ impl BlockQueue {
 	}
 
 	/// Removes up to `max` verified blocks from the queue
-	pub fn drain(&mut self, max: usize) -> Vec<PreVerifiedBlock> {
-		let mut verification = self.verification.lock().unwrap();
-		let count = min(max, verification.verified.len());
+	pub fn drain(&self, max: usize) -> Vec<PreVerifiedBlock> {
+		let mut verified = self.verification.verified.lock().unwrap();
+		let count = min(max, verified.len());
 		let mut result = Vec::with_capacity(count);
 		for _ in 0..count {
-			let block = verification.verified.pop_front().unwrap();
+			let block = verified.pop_front().unwrap();
 			result.push(block);
 		}
 		self.ready_signal.reset();
-		if !verification.verified.is_empty() {
+		if !verified.is_empty() {
 			self.ready_signal.set();
 		}
 		result
@@ -329,11 +342,10 @@ impl BlockQueue {
 
 	/// Get queue status.
 	pub fn queue_info(&self) -> BlockQueueInfo {
-		let verification = self.verification.lock().unwrap();
 		BlockQueueInfo {
-			verified_queue_size: verification.verified.len(),
-			unverified_queue_size: verification.unverified.len(),
-			verifying_queue_size: verification.verifying.len(),
+			unverified_queue_size: self.verification.unverified.lock().unwrap().len(),
+			verifying_queue_size: self.verification.verifying.lock().unwrap().len(),
+			verified_queue_size: self.verification.verified.lock().unwrap().len(),
 		}
 	}
 }
diff --git a/ethcore/src/client.rs b/ethcore/src/client.rs
index c3ec4b4d0..0c8580117 100644
--- a/ethcore/src/client.rs
+++ b/ethcore/src/client.rs
@@ -172,7 +172,7 @@ pub struct Client {
 	chain: Arc<RwLock<BlockChain>>,
 	engine: Arc<Box<Engine>>,
 	state_db: Mutex<JournalDB>,
-	block_queue: RwLock<BlockQueue>,
+	block_queue: BlockQueue,
 	report: RwLock<ClientReport>,
 	import_lock: Mutex<()>,
 	panic_handler: Arc<PanicHandler>,
@@ -231,7 +231,7 @@ impl Client {
 			chain: chain,
 			engine: engine,
 			state_db: Mutex::new(state_db),
-			block_queue: RwLock::new(block_queue),
+			block_queue: block_queue,
 			report: RwLock::new(Default::default()),
 			import_lock: Mutex::new(()),
 			panic_handler: panic_handler
@@ -240,7 +240,7 @@ impl Client {
 
 	/// Flush the block import queue.
 	pub fn flush_queue(&self) {
-		self.block_queue.write().unwrap().flush();
+		self.block_queue.flush();
 	}
 
 	/// This is triggered by a message coming from a block queue when the block is ready for insertion
@@ -248,11 +248,11 @@ impl Client {
 		let mut ret = 0;
 		let mut bad = HashSet::new();
 		let _import_lock = self.import_lock.lock();
-		let blocks = self.block_queue.write().unwrap().drain(128);
+		let blocks = self.block_queue.drain(128);
 		let mut good_blocks = Vec::with_capacity(128);
 		for block in blocks {
 			if bad.contains(&block.header.parent_hash) {
-				self.block_queue.write().unwrap().mark_as_bad(&block.header.hash());
+				self.block_queue.mark_as_bad(&block.header.hash());
 				bad.insert(block.header.hash());
 				continue;
 			}
@@ -260,7 +260,7 @@ impl Client {
 			let header = &block.header;
 			if let Err(e) = verify_block_family(&header, &block.bytes, self.engine.deref().deref(), self.chain.read().unwrap().deref()) {
 				warn!(target: "client", "Stage 3 block verification failed for #{} ({})\nError: {:?}", header.number(), header.hash(), e);
-				self.block_queue.write().unwrap().mark_as_bad(&header.hash());
+				self.block_queue.mark_as_bad(&header.hash());
 				bad.insert(block.header.hash());
 				break;
 			};
@@ -268,7 +268,7 @@ impl Client {
 				Some(p) => p,
 				None => {
 					warn!(target: "client", "Block import failed for #{} ({}): Parent not found ({}) ", header.number(), header.hash(), header.parent_hash);
-					self.block_queue.write().unwrap().mark_as_bad(&header.hash());
+					self.block_queue.mark_as_bad(&header.hash());
 					bad.insert(block.header.hash());
 					break;
 				},
@@ -292,13 +292,13 @@ impl Client {
 				Err(e) => {
 					warn!(target: "client", "Block import failed for #{} ({})\nError: {:?}", header.number(), header.hash(), e);
 					bad.insert(block.header.hash());
-					self.block_queue.write().unwrap().mark_as_bad(&header.hash());
+					self.block_queue.mark_as_bad(&header.hash());
 					break;
 				}
 			};
 			if let Err(e) = verify_block_final(&header, result.block().header()) {
 				warn!(target: "client", "Stage 4 block verification failed for #{} ({})\nError: {:?}", header.number(), header.hash(), e);
-				self.block_queue.write().unwrap().mark_as_bad(&header.hash());
+				self.block_queue.mark_as_bad(&header.hash());
 				break;
 			}
 
@@ -317,8 +317,8 @@ impl Client {
 			trace!(target: "client", "Imported #{} ({})", header.number(), header.hash());
 			ret += 1;
 		}
-		self.block_queue.write().unwrap().mark_as_good(&good_blocks);
-		if !good_blocks.is_empty() && self.block_queue.read().unwrap().queue_info().is_empty() {
+		self.block_queue.mark_as_good(&good_blocks);
+		if !good_blocks.is_empty() && self.block_queue.queue_info().is_empty() {
 			io.send(NetworkIoMessage::User(SyncMessage::BlockVerified)).unwrap();
 		}
 		ret
@@ -389,7 +389,7 @@ impl BlockChainClient for Client {
 		let chain = self.chain.read().unwrap();
 		match Self::block_hash(&chain, id) {
 			Some(ref hash) if chain.is_known(hash) => BlockStatus::InChain,
-			Some(hash) => self.block_queue.read().unwrap().block_status(&hash),
+			Some(hash) => self.block_queue.block_status(&hash),
 			None => BlockStatus::Unknown
 		}
 	}
@@ -434,15 +434,15 @@ impl BlockChainClient for Client {
 		if self.block_status(BlockId::Hash(header.parent_hash)) == BlockStatus::Unknown {
 			return Err(ImportError::UnknownParent);
 		}
-		self.block_queue.write().unwrap().import_block(bytes)
+		self.block_queue.import_block(bytes)
 	}
 
 	fn queue_info(&self) -> BlockQueueInfo {
-		self.block_queue.read().unwrap().queue_info()
+		self.block_queue.queue_info()
 	}
 
 	fn clear_queue(&self) {
-		self.block_queue.write().unwrap().clear();
+		self.block_queue.clear();
 	}
 
 	fn chain_info(&self) -> BlockChainInfo {
diff --git a/ethcore/src/verification.rs b/ethcore/src/verification.rs
index c7d5e265f..fa9467e95 100644
--- a/ethcore/src/verification.rs
+++ b/ethcore/src/verification.rs
@@ -57,18 +57,12 @@ pub fn verify_block_basic(header: &Header, bytes: &[u8], engine: &Engine) -> Res
 /// Still operates on a individual block
 /// Returns a PreVerifiedBlock structure populated with transactions
 pub fn verify_block_unordered(header: Header, bytes: Bytes, engine: &Engine) -> Result<PreVerifiedBlock, Error> {
-	try!(engine.verify_block_unordered(&header, Some(&bytes)));
-	for u in Rlp::new(&bytes).at(2).iter().map(|rlp| rlp.as_val::<Header>()) {
-		try!(engine.verify_block_unordered(&u, None));
-	}
 	// Verify transactions. 
 	let mut transactions = Vec::new();
-	{
-		let v = BlockView::new(&bytes);
-		for t in v.transactions() {
-			try!(engine.verify_transaction(&t, &header));
-			transactions.push(t);
-		}
+	let v = BlockView::new(&bytes);
+	for t in v.transactions() {
+		try!(engine.verify_transaction(&t, &header));
+		transactions.push(t);
 	}
 	Ok(PreVerifiedBlock {
 		header: header,
diff --git a/util/sha3/build.rs b/util/sha3/build.rs
index bbe16d720..9eb36fdb9 100644
--- a/util/sha3/build.rs
+++ b/util/sha3/build.rs
@@ -21,6 +21,6 @@
 extern crate gcc;
 
 fn main() {
-    gcc::compile_library("libtinykeccak.a", &["src/tinykeccak.c"]);
+	gcc::Config::new().file("src/tinykeccak.c").flag("-O3").compile("libtinykeccak.a");
 }
 
diff --git a/util/src/lib.rs b/util/src/lib.rs
index 2b7438cf3..5c8bd4fb0 100644
--- a/util/src/lib.rs
+++ b/util/src/lib.rs
@@ -143,6 +143,7 @@ pub mod network;
 pub mod log;
 pub mod panics;
 pub mod keys;
+mod thread;
 
 pub use common::*;
 pub use misc::*;
@@ -163,4 +164,5 @@ pub use semantic_version::*;
 pub use network::*;
 pub use io::*;
 pub use log::*;
+pub use thread::*;
 
diff --git a/util/src/thread.rs b/util/src/thread.rs
new file mode 100644
index 000000000..b86ca3e86
--- /dev/null
+++ b/util/src/thread.rs
@@ -0,0 +1,43 @@
+// Copyright 2015, 2016 Ethcore (UK) Ltd.
+// This file is part of Parity.
+
+// Parity is free software: you can redistribute it and/or modify
+// it under the terms of the GNU General Public License as published by
+// the Free Software Foundation, either version 3 of the License, or
+// (at your option) any later version.
+
+// Parity is distributed in the hope that it will be useful,
+// but WITHOUT ANY WARRANTY; without even the implied warranty of
+// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
+// GNU General Public License for more details.
+
+// You should have received a copy of the GNU General Public License
+// along with Parity.  If not, see <http://www.gnu.org/licenses/>.
+
+//! Thread management helpers
+
+use libc::{c_int, pthread_self, pthread_t};
+
+#[repr(C)]
+struct sched_param {
+    priority: c_int,
+    padding: c_int,
+}
+
+extern {
+	fn setpriority(which: c_int, who: c_int, prio: c_int) -> c_int;
+	fn pthread_setschedparam(thread: pthread_t, policy: c_int, param: *const sched_param) -> c_int;
+}
+const PRIO_DARWIN_THREAD: c_int = 3;
+const PRIO_DARWIN_BG: c_int = 0x1000;
+const SCHED_RR: c_int = 2;
+
+/// Lower thread priority and put it into background mode
+#[cfg(target_os="macos")]
+pub fn lower_thread_priority() {
+	let sp = sched_param { priority: 0, padding: 0 };
+	if unsafe { pthread_setschedparam(pthread_self(), SCHED_RR, &sp) } == -1 {
+		trace!("Could not decrease thread piority");
+	}
+	//unsafe { setpriority(PRIO_DARWIN_THREAD, 0, PRIO_DARWIN_BG); }
+}
