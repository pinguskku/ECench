commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
commit f826ac35e32c20f667101ad4eed7c84c745ef088
Author: Marek Kotewicz <marek.kotewicz@gmail.com>
Date:   Sun Jul 15 11:01:47 2018 +0200

    Removed redundant struct bounds and unnecessary data copying (#9096)
    
    * Removed redundant struct bounds and unnecessary data copying
    
    * Updated docs, removed redundant bindings

diff --git a/ethcore/src/block.rs b/ethcore/src/block.rs
index ba21cb417..43400895f 100644
--- a/ethcore/src/block.rs
+++ b/ethcore/src/block.rs
@@ -14,7 +14,22 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-//! Blockchain block.
+//! Base data structure of this module is `Block`.
+//!
+//! Blocks can be produced by a local node or they may be received from the network.
+//!
+//! To create a block locally, we start with an `OpenBlock`. This block is mutable
+//! and can be appended to with transactions and uncles.
+//!
+//! When ready, `OpenBlock` can be closed and turned into a `ClosedBlock`. A `ClosedBlock` can
+//! be reopend again by a miner under certain circumstances. On block close, state commit is
+//! performed.
+//!
+//! `LockedBlock` is a version of a `ClosedBlock` that cannot be reopened. It can be sealed
+//! using an engine.
+//!
+//! `ExecutedBlock` is an underlaying data structure used by all structs above to store block
+//! related info.
 
 use std::cmp;
 use std::collections::HashSet;
@@ -85,16 +100,26 @@ impl Decodable for Block {
 /// An internal type for a block's common elements.
 #[derive(Clone)]
 pub struct ExecutedBlock {
-	header: Header,
-	transactions: Vec<SignedTransaction>,
-	uncles: Vec<Header>,
-	receipts: Vec<Receipt>,
-	transactions_set: HashSet<H256>,
-	state: State<StateDB>,
-	traces: Tracing,
-	last_hashes: Arc<LastHashes>,
-	is_finalized: bool,
-	metadata: Option<Vec<u8>>,
+	/// Executed block header.
+	pub header: Header,
+	/// Executed transactions.
+	pub transactions: Vec<SignedTransaction>,
+	/// Uncles.
+	pub uncles: Vec<Header>,
+	/// Transaction receipts.
+	pub receipts: Vec<Receipt>,
+	/// Hashes of already executed transactions.
+	pub transactions_set: HashSet<H256>,
+	/// Underlaying state.
+	pub state: State<StateDB>,
+	/// Transaction traces.
+	pub traces: Tracing,
+	/// Hashes of last 256 blocks.
+	pub last_hashes: Arc<LastHashes>,
+	/// Finalization flag.
+	pub is_finalized: bool,
+	/// Block metadata.
+	pub metadata: Option<Vec<u8>>,
 }
 
 impl ExecutedBlock {
@@ -169,20 +194,14 @@ pub trait IsBlock {
 	/// Get all information on receipts in this block.
 	fn receipts(&self) -> &[Receipt] { &self.block().receipts }
 
-	/// Get all information concerning transaction tracing in this block.
-	fn traces(&self) -> &Tracing { &self.block().traces }
-
 	/// Get all uncles in this block.
 	fn uncles(&self) -> &[Header] { &self.block().uncles }
-
-	/// Get tracing enabled flag for this block.
-	fn tracing_enabled(&self) -> bool { self.block().traces.is_enabled() }
 }
 
-/// Trait for a object that has a state database.
+/// Trait for an object that owns an `ExecutedBlock`
 pub trait Drain {
-	/// Drop this object and return the underlying database.
-	fn drain(self) -> StateDB;
+	/// Returns `ExecutedBlock`
+	fn drain(self) -> ExecutedBlock;
 }
 
 impl IsBlock for ExecutedBlock {
@@ -488,11 +507,11 @@ impl<'x> IsBlock for OpenBlock<'x> {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for ClosedBlock {
+impl IsBlock for ClosedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
-impl<'x> IsBlock for LockedBlock {
+impl IsBlock for LockedBlock {
 	fn block(&self) -> &ExecutedBlock { &self.block }
 }
 
@@ -580,9 +599,8 @@ impl LockedBlock {
 }
 
 impl Drain for LockedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -598,9 +616,8 @@ impl SealedBlock {
 }
 
 impl Drain for SealedBlock {
-	/// Drop this object and return the underlieing database.
-	fn drain(self) -> StateDB {
-		self.block.state.drop().1
+	fn drain(self) -> ExecutedBlock {
+		self.block
 	}
 }
 
@@ -788,14 +805,14 @@ mod tests {
 		let b = OpenBlock::new(engine, Default::default(), false, db, &genesis_header, last_hashes.clone(), Address::zero(), (3141562.into(), 31415620.into()), vec![], false, &mut Vec::new().into_iter()).unwrap()
 			.close_and_lock().seal(engine, vec![]).unwrap();
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
 
 		assert_eq!(e.rlp_bytes(), orig_bytes);
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
@@ -819,7 +836,7 @@ mod tests {
 		let b = open_block.close_and_lock().seal(engine, vec![]).unwrap();
 
 		let orig_bytes = b.rlp_bytes();
-		let orig_db = b.drain();
+		let orig_db = b.drain().state.drop().1;
 
 		let db = spec.ensure_db_good(get_temp_state_db(), &Default::default()).unwrap();
 		let e = enact_and_seal(&orig_bytes, engine, false, db, &genesis_header, last_hashes, Default::default()).unwrap();
@@ -829,7 +846,7 @@ mod tests {
 		let uncles = view!(BlockView, &bytes).uncles();
 		assert_eq!(uncles[1].extra_data(), b"uncle2");
 
-		let db = e.drain();
+		let db = e.drain().state.drop().1;
 		assert_eq!(orig_db.journal_db().keys(), db.journal_db().keys());
 		assert!(orig_db.journal_db().keys().iter().filter(|k| orig_db.journal_db().get(k.0) != db.journal_db().get(k.0)).next() == None);
 	}
diff --git a/ethcore/src/client/client.rs b/ethcore/src/client/client.rs
index 3eb0a7815..3a992fcb2 100644
--- a/ethcore/src/client/client.rs
+++ b/ethcore/src/client/client.rs
@@ -76,7 +76,6 @@ use verification;
 use verification::{PreverifiedBlock, Verifier};
 use verification::queue::BlockQueue;
 use views::BlockView;
-use parity_machine::{Finalizable, WithMetadata};
 
 // re-export
 pub use types::blockchain_info::BlockChainInfo;
@@ -290,7 +289,7 @@ impl Importer {
 					continue;
 				}
 
-				if let Ok(closed_block) = self.check_and_close_block(block, client) {
+				if let Ok(closed_block) = self.check_and_lock_block(block, client) {
 					if self.engine.is_proposal(&header) {
 						self.block_queue.mark_as_good(&[hash]);
 						proposed_blocks.push(bytes);
@@ -345,7 +344,7 @@ impl Importer {
 		imported
 	}
 
-	fn check_and_close_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
+	fn check_and_lock_block(&self, block: PreverifiedBlock, client: &Client) -> Result<LockedBlock, ()> {
 		let engine = &*self.engine;
 		let header = block.header.clone();
 
@@ -459,32 +458,28 @@ impl Importer {
 	// it is for reconstructing the state transition.
 	//
 	// The header passed is from the original block data and is sealed.
-	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: IsBlock + Drain {
+	fn commit_block<B>(&self, block: B, header: &Header, block_data: &[u8], client: &Client) -> ImportRoute where B: Drain {
 		let hash = &header.hash();
 		let number = header.number();
 		let parent = header.parent_hash();
 		let chain = client.chain.read();
 
 		// Commit results
-		let receipts = block.receipts().to_owned();
-		let traces = block.traces().clone().drain();
-
+		let block = block.drain();
 		assert_eq!(header.hash(), view!(BlockView, block_data).header_view().hash());
 
-		//let traces = From::from(block.traces().clone().unwrap_or_else(Vec::new));
-
 		let mut batch = DBTransaction::new();
 
-		let ancestry_actions = self.engine.ancestry_actions(block.block(), &mut chain.ancestry_with_metadata_iter(*parent));
+		let ancestry_actions = self.engine.ancestry_actions(&block, &mut chain.ancestry_with_metadata_iter(*parent));
 
+		let receipts = block.receipts;
+		let traces = block.traces.drain();
 		let best_hash = chain.best_block_hash();
-		let metadata = block.block().metadata().map(Into::into);
-		let is_finalized = block.block().is_finalized();
 
 		let new = ExtendedHeader {
 			header: header.clone(),
-			is_finalized: is_finalized,
-			metadata: metadata,
+			is_finalized: block.is_finalized,
+			metadata: block.metadata,
 			parent_total_difficulty: chain.block_details(&parent).expect("Parent block is in the database; qed").total_difficulty
 		};
 
@@ -516,7 +511,7 @@ impl Importer {
 		// CHECK! I *think* this is fine, even if the state_root is equal to another
 		// already-imported block of the same number.
 		// TODO: Prove it with a test.
-		let mut state = block.drain();
+		let mut state = block.state.drop().1;
 
 		// check epoch end signal, potentially generating a proof on the current
 		// state.
@@ -539,7 +534,7 @@ impl Importer {
 
 		let route = chain.insert_block(&mut batch, block_data, receipts.clone(), ExtrasInsert {
 			fork_choice: fork_choice,
-			is_finalized: is_finalized,
+			is_finalized: block.is_finalized,
 			metadata: new.metadata,
 		});
 
diff --git a/ethcore/src/test_helpers.rs b/ethcore/src/test_helpers.rs
index 85ddd34eb..90ab15598 100644
--- a/ethcore/src/test_helpers.rs
+++ b/ethcore/src/test_helpers.rs
@@ -179,7 +179,7 @@ pub fn generate_dummy_client_with_spec_accounts_and_data<F>(test_spec: F, accoun
 		}
 
 		last_header = view!(BlockView, &b.rlp_bytes()).header();
-		db = b.drain();
+		db = b.drain().state.drop().1;
 	}
 	client.flush_queue();
 	client.import_verified_blocks();
diff --git a/ethcore/src/tests/trace.rs b/ethcore/src/tests/trace.rs
index 350f2b1b7..fd0604cf5 100644
--- a/ethcore/src/tests/trace.rs
+++ b/ethcore/src/tests/trace.rs
@@ -97,7 +97,7 @@ fn can_trace_block_and_uncle_reward() {
 
 	last_header = view!(BlockView, &root_block.rlp_bytes()).header();
 	let root_header = last_header.clone();
-	db = root_block.drain();
+	db = root_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
@@ -125,7 +125,7 @@ fn can_trace_block_and_uncle_reward() {
 	}
 
 	last_header = view!(BlockView,&parent_block.rlp_bytes()).header();
-	db = parent_block.drain();
+	db = parent_block.drain().state.drop().1;
 
 	last_hashes.push(last_header.hash());
 
diff --git a/util/using_queue/src/lib.rs b/util/using_queue/src/lib.rs
index 42eb1cbe3..b2c94b3f4 100644
--- a/util/using_queue/src/lib.rs
+++ b/util/using_queue/src/lib.rs
@@ -19,7 +19,7 @@
 /// Special queue-like datastructure that includes the notion of
 /// usage to avoid items that were queued but never used from making it into
 /// the queue.
-pub struct UsingQueue<T> where T: Clone {
+pub struct UsingQueue<T> {
 	/// Not yet being sealed by a miner, but if one asks for work, we'd prefer they do this.
 	pending: Option<T>,
 	/// Currently being sealed by miners.
@@ -36,7 +36,7 @@ pub enum GetAction {
 	Clone,
 }
 
-impl<T> UsingQueue<T> where T: Clone {
+impl<T> UsingQueue<T> {
 	/// Create a new struct with a maximum size of `max_size`.
 	pub fn new(max_size: usize) -> UsingQueue<T> {
 		UsingQueue {
@@ -88,12 +88,12 @@ impl<T> UsingQueue<T> where T: Clone {
 
 	/// Returns `Some` item which is the first that `f` returns `true` with a reference to it
 	/// as a parameter or `None` if no such item exists in the queue.
-	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	fn clone_used_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		self.in_use.iter().find(|r| predicate(r)).cloned()
 	}
 
 	/// Fork-function for `take_used_if` and `clone_used_if`.
-	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn get_used_if<P>(&mut self, action: GetAction, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		match action {
 			GetAction::Take => self.take_used_if(predicate),
 			GetAction::Clone => self.clone_used_if(predicate),
@@ -104,7 +104,7 @@ impl<T> UsingQueue<T> where T: Clone {
 	/// a parameter, otherwise `None`.
 	/// Will not destroy a block if a reference to it has previously been returned by `use_last_ref`,
 	/// but rather clone it.
-	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool {
+	pub fn pop_if<P>(&mut self, predicate: P) -> Option<T> where P: Fn(&T) -> bool, T: Clone {
 		// a bit clumsy - TODO: think about a nicer way of expressing this.
 		if let Some(x) = self.pending.take() {
 			if predicate(&x) {
