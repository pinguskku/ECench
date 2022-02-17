commit 8e8679807dbb8df6456172fdfa1396b7f091d267
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Wed May 2 09:31:06 2018 +0200

    Transaction Pool improvements (#8470)
    
    * Don't use ethereum_types in transaction pool.
    
    * Hide internal insertion_id.
    
    * Fix tests.
    
    * Review grumbles.

diff --git a/miner/src/pool/mod.rs b/miner/src/pool/mod.rs
index 7950510c6..45d28f3c1 100644
--- a/miner/src/pool/mod.rs
+++ b/miner/src/pool/mod.rs
@@ -105,6 +105,11 @@ impl VerifiedTransaction {
 		self.priority
 	}
 
+	/// Gets transaction insertion id.
+	pub(crate) fn insertion_id(&self) -> usize {
+		self.insertion_id
+	}
+
 	/// Gets wrapped `SignedTransaction`
 	pub fn signed(&self) -> &transaction::SignedTransaction {
 		&self.transaction
@@ -114,9 +119,13 @@ impl VerifiedTransaction {
 	pub fn pending(&self) -> &transaction::PendingTransaction {
 		&self.transaction
 	}
+
 }
 
 impl txpool::VerifiedTransaction for VerifiedTransaction {
+	type Hash = H256;
+	type Sender = Address;
+
 	fn hash(&self) -> &H256 {
 		&self.hash
 	}
@@ -128,8 +137,4 @@ impl txpool::VerifiedTransaction for VerifiedTransaction {
 	fn sender(&self) -> &Address {
 		&self.sender
 	}
-
-	fn insertion_id(&self) -> u64 {
-		self.insertion_id as u64
-	}
 }
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index edc092a11..8cf4534b7 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -282,11 +282,11 @@ impl TransactionQueue {
 		// We want to clear stale transactions from the queue as well.
 		// (Transactions that are occuping the queue for a long time without being included)
 		let stale_id = {
-			let current_id = self.insertion_id.load(atomic::Ordering::Relaxed) as u64;
+			let current_id = self.insertion_id.load(atomic::Ordering::Relaxed);
 			// wait at least for half of the queue to be replaced
 			let gap = self.pool.read().options().max_count / 2;
 			// but never less than 100 transactions
-			let gap = cmp::max(100, gap) as u64;
+			let gap = cmp::max(100, gap);
 
 			current_id.checked_sub(gap)
 		};
diff --git a/miner/src/pool/ready.rs b/miner/src/pool/ready.rs
index 54b5aec3a..c2829b34a 100644
--- a/miner/src/pool/ready.rs
+++ b/miner/src/pool/ready.rs
@@ -54,14 +54,14 @@ pub struct State<C> {
 	nonces: HashMap<Address, U256>,
 	state: C,
 	max_nonce: Option<U256>,
-	stale_id: Option<u64>,
+	stale_id: Option<usize>,
 }
 
 impl<C> State<C> {
 	/// Create new State checker, given client interface.
 	pub fn new(
 		state: C,
-		stale_id: Option<u64>,
+		stale_id: Option<usize>,
 		max_nonce: Option<U256>,
 	) -> Self {
 		State {
@@ -91,10 +91,10 @@ impl<C: NonceClient> txpool::Ready<VerifiedTransaction> for State<C> {
 		match tx.transaction.nonce.cmp(nonce) {
 			// Before marking as future check for stale ids
 			cmp::Ordering::Greater => match self.stale_id {
-				Some(id) if tx.insertion_id() < id => txpool::Readiness::Stalled,
+				Some(id) if tx.insertion_id() < id => txpool::Readiness::Stale,
 				_ => txpool::Readiness::Future,
 			},
-			cmp::Ordering::Less => txpool::Readiness::Stalled,
+			cmp::Ordering::Less => txpool::Readiness::Stale,
 			cmp::Ordering::Equal => {
 				*nonce = *nonce + 1.into();
 				txpool::Readiness::Ready
@@ -178,7 +178,7 @@ mod tests {
 		let res = State::new(TestClient::new().with_nonce(125), None, None).is_ready(&tx);
 
 		// then
-		assert_eq!(res, txpool::Readiness::Stalled);
+		assert_eq!(res, txpool::Readiness::Stale);
 	}
 
 	#[test]
@@ -190,7 +190,7 @@ mod tests {
 		let res = State::new(TestClient::new(), Some(1), None).is_ready(&tx);
 
 		// then
-		assert_eq!(res, txpool::Readiness::Stalled);
+		assert_eq!(res, txpool::Readiness::Stale);
 	}
 
 	#[test]
diff --git a/miner/src/pool/scoring.rs b/miner/src/pool/scoring.rs
index b9f074ecb..eaf069833 100644
--- a/miner/src/pool/scoring.rs
+++ b/miner/src/pool/scoring.rs
@@ -28,7 +28,6 @@
 //! from our local node (own transactions).
 
 use std::cmp;
-use std::sync::Arc;
 
 use ethereum_types::U256;
 use txpool;
@@ -69,7 +68,7 @@ impl txpool::Scoring<VerifiedTransaction> for NonceAndGasPrice {
 		}
 	}
 
-	fn update_scores(&self, txs: &[Arc<VerifiedTransaction>], scores: &mut [U256], change: txpool::scoring::Change) {
+	fn update_scores(&self, txs: &[txpool::Transaction<VerifiedTransaction>], scores: &mut [U256], change: txpool::scoring::Change) {
 		use self::txpool::scoring::Change;
 
 		match change {
@@ -79,7 +78,7 @@ impl txpool::Scoring<VerifiedTransaction> for NonceAndGasPrice {
 				assert!(i < txs.len());
 				assert!(i < scores.len());
 
-				scores[i] = txs[i].transaction.gas_price;
+				scores[i] = txs[i].transaction.transaction.gas_price;
 				let boost = match txs[i].priority() {
 					super::Priority::Local => 15,
 					super::Priority::Retracted => 10,
@@ -116,6 +115,7 @@ impl txpool::Scoring<VerifiedTransaction> for NonceAndGasPrice {
 mod tests {
 	use super::*;
 
+	use std::sync::Arc;
 	use pool::tests::tx::{Tx, TxExt};
 	use txpool::Scoring;
 
@@ -131,7 +131,10 @@ mod tests {
 				1 => ::pool::Priority::Retracted,
 				_ => ::pool::Priority::Regular,
 			};
-			Arc::new(verified)
+			txpool::Transaction {
+				insertion_id: 0,
+				transaction: Arc::new(verified),
+			}
 		}).collect::<Vec<_>>();
 		let initial_scores = vec![U256::from(0), 0.into(), 0.into()];
 
diff --git a/transaction-pool/Cargo.toml b/transaction-pool/Cargo.toml
index b86307811..342c376f6 100644
--- a/transaction-pool/Cargo.toml
+++ b/transaction-pool/Cargo.toml
@@ -10,4 +10,6 @@ error-chain = "0.11"
 log = "0.3"
 smallvec = "0.4"
 trace-time = { path = "../util/trace-time" }
+
+[dev-dependencies]
 ethereum-types = "0.3"
diff --git a/transaction-pool/src/error.rs b/transaction-pool/src/error.rs
index 2e8ac7398..4cf221a71 100644
--- a/transaction-pool/src/error.rs
+++ b/transaction-pool/src/error.rs
@@ -14,24 +14,26 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use ethereum_types::H256;
+/// Error chain doesn't let us have generic types.
+/// So the hashes are converted to debug strings for easy display.
+type Hash = String;
 
 error_chain! {
 	errors {
 		/// Transaction is already imported
-		AlreadyImported(hash: H256) {
+		AlreadyImported(hash: Hash) {
 			description("transaction is already in the pool"),
-			display("[{:?}] already imported", hash)
+			display("[{}] already imported", hash)
 		}
 		/// Transaction is too cheap to enter the queue
-		TooCheapToEnter(hash: H256, min_score: String) {
+		TooCheapToEnter(hash: Hash, min_score: String) {
 			description("the pool is full and transaction is too cheap to replace any transaction"),
-			display("[{:?}] too cheap to enter the pool. Min score: {}", hash, min_score)
+			display("[{}] too cheap to enter the pool. Min score: {}", hash, min_score)
 		}
 		/// Transaction is too cheap to replace existing transaction that occupies the same slot.
-		TooCheapToReplace(old_hash: H256, hash: H256) {
+		TooCheapToReplace(old_hash: Hash, hash: Hash) {
 			description("transaction is too cheap to replace existing transaction in the pool"),
-			display("[{:?}] too cheap to replace: {:?}", hash, old_hash)
+			display("[{}] too cheap to replace: {}", hash, old_hash)
 		}
 	}
 }
diff --git a/transaction-pool/src/lib.rs b/transaction-pool/src/lib.rs
index 33d17f4b0..4a1bdcde1 100644
--- a/transaction-pool/src/lib.rs
+++ b/transaction-pool/src/lib.rs
@@ -69,14 +69,15 @@
 #![warn(missing_docs)]
 
 extern crate smallvec;
-extern crate ethereum_types;
+extern crate trace_time;
 
 #[macro_use]
 extern crate error_chain;
 #[macro_use]
 extern crate log;
 
-extern crate trace_time;
+#[cfg(test)]
+extern crate ethereum_types;
 
 #[cfg(test)]
 mod tests;
@@ -95,27 +96,29 @@ pub mod scoring;
 pub use self::error::{Error, ErrorKind};
 pub use self::listener::{Listener, NoopListener};
 pub use self::options::Options;
-pub use self::pool::{Pool, PendingIterator};
+pub use self::pool::{Pool, PendingIterator, Transaction};
 pub use self::ready::{Ready, Readiness};
 pub use self::scoring::Scoring;
 pub use self::status::{LightStatus, Status};
 pub use self::verifier::Verifier;
 
 use std::fmt;
-
-use ethereum_types::{H256, Address};
+use std::hash::Hash;
 
 /// Already verified transaction that can be safely queued.
 pub trait VerifiedTransaction: fmt::Debug {
+	/// Transaction hash type.
+	type Hash: fmt::Debug + fmt::LowerHex + Eq + Clone + Hash;
+
+	/// Transaction sender type.
+	type Sender: fmt::Debug + Eq + Clone + Hash;
+
 	/// Transaction hash
-	fn hash(&self) -> &H256;
+	fn hash(&self) -> &Self::Hash;
 
 	/// Memory usage
 	fn mem_usage(&self) -> usize;
 
 	/// Transaction sender
-	fn sender(&self) -> &Address;
-
-	/// Unique index of insertion (lower = older).
-	fn insertion_id(&self) -> u64;
+	fn sender(&self) -> &Self::Sender;
 }
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index fa28cdcdf..5cb6e479b 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -17,8 +17,6 @@
 use std::sync::Arc;
 use std::collections::{HashMap, BTreeSet};
 
-use ethereum_types::{H160, H256};
-
 use error;
 use listener::{Listener, NoopListener};
 use options::Options;
@@ -29,21 +27,51 @@ use transactions::{AddResult, Transactions};
 
 use {VerifiedTransaction};
 
-type Sender = H160;
+/// Internal representation of transaction.
+///
+/// Includes unique insertion id that can be used for scoring explictly,
+/// but internally is used to resolve conflicts in case of equal scoring
+/// (newer transactionsa are preferred).
+#[derive(Debug)]
+pub struct Transaction<T> {
+	/// Sequential id of the transaction
+	pub insertion_id: u64,
+	/// Shared transaction
+	pub transaction: Arc<T>,
+}
+
+impl<T> Clone for Transaction<T> {
+	fn clone(&self) -> Self {
+		Transaction {
+			insertion_id: self.insertion_id,
+			transaction: self.transaction.clone(),
+		}
+	}
+}
+
+impl<T> ::std::ops::Deref for Transaction<T> {
+	type Target = Arc<T>;
+
+	fn deref(&self) -> &Self::Target {
+		&self.transaction
+	}
+}
 
 /// A transaction pool.
 #[derive(Debug)]
-pub struct Pool<T, S: Scoring<T>, L = NoopListener> {
+pub struct Pool<T: VerifiedTransaction, S: Scoring<T>, L = NoopListener> {
 	listener: L,
 	scoring: S,
 	options: Options,
 	mem_usage: usize,
 
-	transactions: HashMap<Sender, Transactions<T, S>>,
-	by_hash: HashMap<H256, Arc<T>>,
+	transactions: HashMap<T::Sender, Transactions<T, S>>,
+	by_hash: HashMap<T::Hash, Transaction<T>>,
 
 	best_transactions: BTreeSet<ScoreWithRef<T, S::Score>>,
 	worst_transactions: BTreeSet<ScoreWithRef<T, S::Score>>,
+
+	insertion_id: u64,
 }
 
 impl<T: VerifiedTransaction, S: Scoring<T> + Default> Default for Pool<T, S> {
@@ -89,6 +117,7 @@ impl<T, S, L> Pool<T, S, L> where
 			by_hash,
 			best_transactions: Default::default(),
 			worst_transactions: Default::default(),
+			insertion_id: 0,
 		}
 
 	}
@@ -104,10 +133,16 @@ impl<T, S, L> Pool<T, S, L> where
 	/// If any limit is reached the transaction with the lowest `Score` is evicted to make room.
 	///
 	/// The `Listener` will be informed on any drops or rejections.
-	pub fn import(&mut self, mut transaction: T) -> error::Result<Arc<T>> {
+	pub fn import(&mut self, transaction: T) -> error::Result<Arc<T>> {
 		let mem_usage = transaction.mem_usage();
 
-		ensure!(!self.by_hash.contains_key(transaction.hash()), error::ErrorKind::AlreadyImported(*transaction.hash()));
+		ensure!(!self.by_hash.contains_key(transaction.hash()), error::ErrorKind::AlreadyImported(format!("{:?}", transaction.hash())));
+
+		self.insertion_id += 1;
+		let mut transaction = Transaction {
+			insertion_id: self.insertion_id,
+			transaction: Arc::new(transaction),
+		};
 
 		// TODO [ToDr] Most likely move this after the transaction is inserted.
 		// Avoid using should_replace, but rather use scoring for that.
@@ -115,7 +150,7 @@ impl<T, S, L> Pool<T, S, L> where
 			let remove_worst = |s: &mut Self, transaction| {
 				match s.remove_worst(&transaction) {
 					Err(err) => {
-						s.listener.rejected(&Arc::new(transaction), err.kind());
+						s.listener.rejected(&transaction, err.kind());
 						Err(err)
 					},
 					Ok(removed) => {
@@ -138,7 +173,7 @@ impl<T, S, L> Pool<T, S, L> where
 		}
 
 		let (result, prev_state, current_state) = {
-			let transactions = self.transactions.entry(*transaction.sender()).or_insert_with(Transactions::default);
+			let transactions = self.transactions.entry(transaction.sender().clone()).or_insert_with(Transactions::default);
 			// get worst and best transactions for comparison
 			let prev = transactions.worst_and_best();
 			let result = transactions.add(transaction, &self.scoring, self.options.max_per_sender);
@@ -153,31 +188,31 @@ impl<T, S, L> Pool<T, S, L> where
 			AddResult::Ok(tx) => {
 				self.listener.added(&tx, None);
 				self.finalize_insert(&tx, None);
-				Ok(tx)
+				Ok(tx.transaction)
 			},
 			AddResult::PushedOut { new, old } |
 			AddResult::Replaced { new, old } => {
 				self.listener.added(&new, Some(&old));
 				self.finalize_insert(&new, Some(&old));
-				Ok(new)
+				Ok(new.transaction)
 			},
 			AddResult::TooCheap { new, old } => {
-				let error = error::ErrorKind::TooCheapToReplace(*old.hash(), *new.hash());
-				self.listener.rejected(&Arc::new(new), &error);
+				let error = error::ErrorKind::TooCheapToReplace(format!("{:x}", old.hash()), format!("{:x}", new.hash()));
+				self.listener.rejected(&new, &error);
 				bail!(error)
 			},
 			AddResult::TooCheapToEnter(new, score) => {
-				let error = error::ErrorKind::TooCheapToEnter(*new.hash(), format!("{:?}", score));
-				self.listener.rejected(&Arc::new(new), &error);
+				let error = error::ErrorKind::TooCheapToEnter(format!("{:x}", new.hash()), format!("{:?}", score));
+				self.listener.rejected(&new, &error);
 				bail!(error)
 			}
 		}
 	}
 
 	/// Updates state of the pool statistics if the transaction was added to a set.
-	fn finalize_insert(&mut self, new: &Arc<T>, old: Option<&Arc<T>>) {
+	fn finalize_insert(&mut self, new: &Transaction<T>, old: Option<&Transaction<T>>) {
 		self.mem_usage += new.mem_usage();
-		self.by_hash.insert(*new.hash(), new.clone());
+		self.by_hash.insert(new.hash().clone(), new.clone());
 
 		if let Some(old) = old {
 			self.finalize_remove(old.hash());
@@ -185,23 +220,23 @@ impl<T, S, L> Pool<T, S, L> where
 	}
 
 	/// Updates the pool statistics if transaction was removed.
-	fn finalize_remove(&mut self, hash: &H256) -> Option<Arc<T>> {
+	fn finalize_remove(&mut self, hash: &T::Hash) -> Option<Arc<T>> {
 		self.by_hash.remove(hash).map(|old| {
-			self.mem_usage -= old.mem_usage();
-			old
+			self.mem_usage -= old.transaction.mem_usage();
+			old.transaction
 		})
 	}
 
 	/// Updates best and worst transactions from a sender.
 	fn update_senders_worst_and_best(
 		&mut self,
-		previous: Option<((S::Score, Arc<T>), (S::Score, Arc<T>))>,
-		current: Option<((S::Score, Arc<T>), (S::Score, Arc<T>))>,
+		previous: Option<((S::Score, Transaction<T>), (S::Score, Transaction<T>))>,
+		current: Option<((S::Score, Transaction<T>), (S::Score, Transaction<T>))>,
 	) {
 		let worst_collection = &mut self.worst_transactions;
 		let best_collection = &mut self.best_transactions;
 
-		let is_same = |a: &(S::Score, Arc<T>), b: &(S::Score, Arc<T>)| {
+		let is_same = |a: &(S::Score, Transaction<T>), b: &(S::Score, Transaction<T>)| {
 			a.0 == b.0 && a.1.hash() == b.1.hash()
 		};
 
@@ -238,19 +273,19 @@ impl<T, S, L> Pool<T, S, L> where
 	}
 
 	/// Attempts to remove the worst transaction from the pool if it's worse than the given one.
-	fn remove_worst(&mut self, transaction: &T) -> error::Result<Arc<T>> {
+	fn remove_worst(&mut self, transaction: &Transaction<T>) -> error::Result<Transaction<T>> {
 		let to_remove = match self.worst_transactions.iter().next_back() {
 			// No elements to remove? and the pool is still full?
 			None => {
 				warn!("The pool is full but there are no transactions to remove.");
-				return Err(error::ErrorKind::TooCheapToEnter(*transaction.hash(), "unknown".into()).into());
+				return Err(error::ErrorKind::TooCheapToEnter(format!("{:?}", transaction.hash()), "unknown".into()).into());
 			},
 			Some(old) => if self.scoring.should_replace(&old.transaction, transaction) {
 				// New transaction is better than the worst one so we can replace it.
 				old.clone()
 			} else {
 				// otherwise fail
-				return Err(error::ErrorKind::TooCheapToEnter(*transaction.hash(), format!("{:?}", old.score)).into())
+				return Err(error::ErrorKind::TooCheapToEnter(format!("{:?}", transaction.hash()), format!("{:?}", old.score)).into())
 			},
 		};
 
@@ -263,7 +298,7 @@ impl<T, S, L> Pool<T, S, L> where
 	}
 
 	/// Removes transaction from sender's transaction `HashMap`.
-	fn remove_from_set<R, F: FnOnce(&mut Transactions<T, S>, &S) -> R>(&mut self, sender: &Sender, f: F) -> Option<R> {
+	fn remove_from_set<R, F: FnOnce(&mut Transactions<T, S>, &S) -> R>(&mut self, sender: &T::Sender, f: F) -> Option<R> {
 		let (prev, next, result) = if let Some(set) = self.transactions.get_mut(sender) {
 			let prev = set.worst_and_best();
 			let result = f(set, &self.scoring);
@@ -286,14 +321,14 @@ impl<T, S, L> Pool<T, S, L> where
 		self.worst_transactions.clear();
 
 		for (_hash, tx) in self.by_hash.drain() {
-			self.listener.dropped(&tx, None)
+			self.listener.dropped(&tx.transaction, None)
 		}
 	}
 
 	/// Removes single transaction from the pool.
 	/// Depending on the `is_invalid` flag the listener
 	/// will either get a `cancelled` or `invalid` notification.
-	pub fn remove(&mut self, hash: &H256, is_invalid: bool) -> Option<Arc<T>> {
+	pub fn remove(&mut self, hash: &T::Hash, is_invalid: bool) -> Option<Arc<T>> {
 		if let Some(tx) = self.finalize_remove(hash) {
 			self.remove_from_set(tx.sender(), |set, scoring| {
 				set.remove(&tx, scoring)
@@ -310,7 +345,7 @@ impl<T, S, L> Pool<T, S, L> where
 	}
 
 	/// Removes all stalled transactions from given sender.
-	fn remove_stalled<R: Ready<T>>(&mut self, sender: &Sender, ready: &mut R) -> usize {
+	fn remove_stalled<R: Ready<T>>(&mut self, sender: &T::Sender, ready: &mut R) -> usize {
 		let removed_from_set = self.remove_from_set(sender, |transactions, scoring| {
 			transactions.cull(ready, scoring)
 		});
@@ -329,7 +364,7 @@ impl<T, S, L> Pool<T, S, L> where
 	}
 
 	/// Removes all stalled transactions from given sender list (or from all senders).
-	pub fn cull<R: Ready<T>>(&mut self, senders: Option<&[Sender]>, mut ready: R) -> usize {
+	pub fn cull<R: Ready<T>>(&mut self, senders: Option<&[T::Sender]>, mut ready: R) -> usize {
 		let mut removed = 0;
 		match senders {
 			Some(senders) => {
@@ -349,13 +384,13 @@ impl<T, S, L> Pool<T, S, L> where
 	}
 
 	/// Returns a transaction if it's part of the pool or `None` otherwise.
-	pub fn find(&self, hash: &H256) -> Option<Arc<T>> {
-		self.by_hash.get(hash).cloned()
+	pub fn find(&self, hash: &T::Hash) -> Option<Arc<T>> {
+		self.by_hash.get(hash).map(|t| t.transaction.clone())
 	}
 
 	/// Returns worst transaction in the queue (if any).
 	pub fn worst_transaction(&self) -> Option<Arc<T>> {
-		self.worst_transactions.iter().next().map(|x| x.transaction.clone())
+		self.worst_transactions.iter().next().map(|x| x.transaction.transaction.clone())
 	}
 
 	/// Returns an iterator of pending (ready) transactions.
@@ -368,7 +403,7 @@ impl<T, S, L> Pool<T, S, L> where
 	}
 
 	/// Returns pending (ready) transactions from given sender.
-	pub fn pending_from_sender<R: Ready<T>>(&self, ready: R, sender: &Sender) -> PendingIterator<T, R, S, L> {
+	pub fn pending_from_sender<R: Ready<T>>(&self, ready: R, sender: &T::Sender) -> PendingIterator<T, R, S, L> {
 		let best_transactions = self.transactions.get(sender)
 			.and_then(|transactions| transactions.worst_and_best())
 			.map(|(_, best)| ScoreWithRef::new(best.0, best.1))
@@ -387,7 +422,7 @@ impl<T, S, L> Pool<T, S, L> where
 	}
 
 	/// Update score of transactions of a particular sender.
-	pub fn update_scores(&mut self, sender: &Sender, event: S::Event) {
+	pub fn update_scores(&mut self, sender: &T::Sender, event: S::Event) {
 		let res = if let Some(set) = self.transactions.get_mut(sender) {
 			let prev = set.worst_and_best();
 			set.update_scores(&self.scoring, event);
@@ -410,7 +445,7 @@ impl<T, S, L> Pool<T, S, L> where
 			let len = transactions.len();
 			for (idx, tx) in transactions.iter().enumerate() {
 				match ready.is_ready(tx) {
-					Readiness::Stalled => status.stalled += 1,
+					Readiness::Stale => status.stalled += 1,
 					Readiness::Ready => status.pending += 1,
 					Readiness::Future => {
 						status.future += len - idx;
@@ -485,7 +520,7 @@ impl<'a, T, R, S, L> Iterator for PendingIterator<'a, T, R, S, L> where
 						self.best_transactions.insert(ScoreWithRef::new(score, tx));
 					}
 
-					return Some(best.transaction)
+					return Some(best.transaction.transaction)
 				},
 				state => trace!("[{:?}] Ignoring {:?} transaction.", best.transaction.hash(), state),
 			}
diff --git a/transaction-pool/src/ready.rs b/transaction-pool/src/ready.rs
index 735244432..aa913a9eb 100644
--- a/transaction-pool/src/ready.rs
+++ b/transaction-pool/src/ready.rs
@@ -17,8 +17,8 @@
 /// Transaction readiness.
 #[derive(Debug, Clone, Copy, PartialEq, Eq)]
 pub enum Readiness {
-	/// The transaction is stalled (and should/will be removed from the pool).
-	Stalled,
+	/// The transaction is stale (and should/will be removed from the pool).
+	Stale,
 	/// The transaction is ready to be included in pending set.
 	Ready,
 	/// The transaction is not yet ready.
diff --git a/transaction-pool/src/scoring.rs b/transaction-pool/src/scoring.rs
index 4e7a9833a..2acfb3374 100644
--- a/transaction-pool/src/scoring.rs
+++ b/transaction-pool/src/scoring.rs
@@ -17,9 +17,7 @@
 //! A transactions ordering abstraction.
 
 use std::{cmp, fmt};
-use std::sync::Arc;
-
-use {VerifiedTransaction};
+use pool::Transaction;
 
 /// Represents a decision what to do with
 /// a new transaction that tries to enter the pool.
@@ -98,7 +96,7 @@ pub trait Scoring<T>: fmt::Debug {
 	/// Updates the transaction scores given a list of transactions and a change to previous scoring.
 	/// NOTE: you can safely assume that both slices have the same length.
 	/// (i.e. score at index `i` represents transaction at the same index)
-	fn update_scores(&self, txs: &[Arc<T>], scores: &mut [Self::Score], change: Change<Self::Event>);
+	fn update_scores(&self, txs: &[Transaction<T>], scores: &mut [Self::Score], change: Change<Self::Event>);
 
 	/// Decides if `new` should push out `old` transaction from the pool.
 	fn should_replace(&self, old: &T, new: &T) -> bool;
@@ -110,7 +108,14 @@ pub struct ScoreWithRef<T, S> {
 	/// Score
 	pub score: S,
 	/// Shared transaction
-	pub transaction: Arc<T>,
+	pub transaction: Transaction<T>,
+}
+
+impl<T, S> ScoreWithRef<T, S> {
+	/// Creates a new `ScoreWithRef`
+	pub fn new(score: S, transaction: Transaction<T>) -> Self {
+		ScoreWithRef { score, transaction }
+	}
 }
 
 impl<T, S: Clone> Clone for ScoreWithRef<T, S> {
@@ -122,30 +127,23 @@ impl<T, S: Clone> Clone for ScoreWithRef<T, S> {
 	}
 }
 
-impl<T, S> ScoreWithRef<T, S> {
-	/// Creates a new `ScoreWithRef`
-	pub fn new(score: S, transaction: Arc<T>) -> Self {
-		ScoreWithRef { score, transaction }
-	}
-}
-
-impl<S: cmp::Ord, T: VerifiedTransaction> Ord for ScoreWithRef<T, S> {
+impl<S: cmp::Ord, T> Ord for ScoreWithRef<T, S> {
 	fn cmp(&self, other: &Self) -> cmp::Ordering {
 		other.score.cmp(&self.score)
-			.then(other.transaction.insertion_id().cmp(&self.transaction.insertion_id()))
+			.then(other.transaction.insertion_id.cmp(&self.transaction.insertion_id))
 	}
 }
 
-impl<S: cmp::Ord, T: VerifiedTransaction> PartialOrd for ScoreWithRef<T, S> {
+impl<S: cmp::Ord, T> PartialOrd for ScoreWithRef<T, S> {
 	fn partial_cmp(&self, other: &Self) -> Option<cmp::Ordering> {
 		Some(self.cmp(other))
 	}
 }
 
-impl<S: cmp::Ord, T: VerifiedTransaction>  PartialEq for ScoreWithRef<T, S> {
+impl<S: cmp::Ord, T>  PartialEq for ScoreWithRef<T, S> {
 	fn eq(&self, other: &Self) -> bool {
-		self.score == other.score && self.transaction.insertion_id() == other.transaction.insertion_id()
+		self.score == other.score && self.transaction.insertion_id == other.transaction.insertion_id
 	}
 }
 
-impl<S: cmp::Ord, T: VerifiedTransaction> Eq for ScoreWithRef<T, S> {}
+impl<S: cmp::Ord, T> Eq for ScoreWithRef<T, S> {}
diff --git a/transaction-pool/src/tests/helpers.rs b/transaction-pool/src/tests/helpers.rs
index ab5b2a334..cfc6641b5 100644
--- a/transaction-pool/src/tests/helpers.rs
+++ b/transaction-pool/src/tests/helpers.rs
@@ -17,9 +17,9 @@
 use std::cmp;
 use std::collections::HashMap;
 
-use ethereum_types::U256;
-use {scoring, Scoring, Ready, Readiness, Address as Sender};
-use super::{Transaction, SharedTransaction};
+use ethereum_types::{H160 as Sender, U256};
+use {pool, scoring, Scoring, Ready, Readiness};
+use super::Transaction;
 
 #[derive(Debug, Default)]
 pub struct DummyScoring;
@@ -44,7 +44,7 @@ impl Scoring<Transaction> for DummyScoring {
 		}
 	}
 
-	fn update_scores(&self, txs: &[SharedTransaction], scores: &mut [Self::Score], change: scoring::Change) {
+	fn update_scores(&self, txs: &[pool::Transaction<Transaction>], scores: &mut [Self::Score], change: scoring::Change) {
 		if let scoring::Change::Event(_) = change {
 			// In case of event reset all scores to 0
 			for i in 0..txs.len() {
@@ -84,7 +84,7 @@ impl Ready<Transaction> for NonceReady {
 				*nonce = *nonce + 1.into();
 				Readiness::Ready
 			},
-			cmp::Ordering::Less => Readiness::Stalled,
+			cmp::Ordering::Less => Readiness::Stale,
 		}
 	}
 }
diff --git a/transaction-pool/src/tests/mod.rs b/transaction-pool/src/tests/mod.rs
index 5113a4663..b21ea3180 100644
--- a/transaction-pool/src/tests/mod.rs
+++ b/transaction-pool/src/tests/mod.rs
@@ -32,15 +32,16 @@ pub struct Transaction {
 	pub gas_price: U256,
 	pub gas: U256,
 	pub sender: Address,
-	pub insertion_id: u64,
 	pub mem_usage: usize,
 }
 
 impl VerifiedTransaction for Transaction {
+	type Hash = H256;
+	type Sender = Address;
+
 	fn hash(&self) -> &H256 { &self.hash }
 	fn mem_usage(&self) -> usize { self.mem_usage }
 	fn sender(&self) -> &Address { &self.sender }
-	fn insertion_id(&self) -> u64 { self.insertion_id }
 }
 
 pub type SharedTransaction = Arc<Transaction>;
@@ -123,7 +124,7 @@ fn should_reject_if_above_count() {
 	// Reject second
 	let tx1 = b.tx().nonce(0).new();
 	let tx2 = b.tx().nonce(1).new();
-	let hash = *tx2.hash();
+	let hash = format!("{:?}", tx2.hash());
 	txq.import(tx1).unwrap();
 	assert_eq!(txq.import(tx2).unwrap_err().kind(), &error::ErrorKind::TooCheapToEnter(hash, "0x0".into()));
 	assert_eq!(txq.light_status().transaction_count, 1);
@@ -149,7 +150,7 @@ fn should_reject_if_above_mem_usage() {
 	// Reject second
 	let tx1 = b.tx().nonce(1).mem_usage(1).new();
 	let tx2 = b.tx().nonce(2).mem_usage(2).new();
-	let hash = *tx2.hash();
+	let hash = format!("{:?}", tx2.hash());
 	txq.import(tx1).unwrap();
 	assert_eq!(txq.import(tx2).unwrap_err().kind(), &error::ErrorKind::TooCheapToEnter(hash, "0x0".into()));
 	assert_eq!(txq.light_status().transaction_count, 1);
@@ -175,7 +176,7 @@ fn should_reject_if_above_sender_count() {
 	// Reject second
 	let tx1 = b.tx().nonce(1).new();
 	let tx2 = b.tx().nonce(2).new();
-	let hash = *tx2.hash();
+	let hash = format!("{:x}", tx2.hash());
 	txq.import(tx1).unwrap();
 	assert_eq!(txq.import(tx2).unwrap_err().kind(), &error::ErrorKind::TooCheapToEnter(hash, "0x0".into()));
 	assert_eq!(txq.light_status().transaction_count, 1);
@@ -185,7 +186,7 @@ fn should_reject_if_above_sender_count() {
 	// Replace first
 	let tx1 = b.tx().nonce(1).new();
 	let tx2 = b.tx().nonce(2).gas_price(2).new();
-	let hash = *tx2.hash();
+	let hash = format!("{:x}", tx2.hash());
 	txq.import(tx1).unwrap();
 	// This results in error because we also compare nonces
 	assert_eq!(txq.import(tx2).unwrap_err().kind(), &error::ErrorKind::TooCheapToEnter(hash, "0x0".into()));
diff --git a/transaction-pool/src/tests/tx_builder.rs b/transaction-pool/src/tests/tx_builder.rs
index e9c1c1d5f..88a881aca 100644
--- a/transaction-pool/src/tests/tx_builder.rs
+++ b/transaction-pool/src/tests/tx_builder.rs
@@ -14,9 +14,6 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
-use std::rc::Rc;
-use std::cell::Cell;
-
 use super::{Transaction, U256, Address};
 
 #[derive(Debug, Default, Clone)]
@@ -26,7 +23,6 @@ pub struct TransactionBuilder {
 	gas: U256,
 	sender: Address,
 	mem_usage: usize,
-	insertion_id: Rc<Cell<u64>>,
 }
 
 impl TransactionBuilder {
@@ -55,11 +51,6 @@ impl TransactionBuilder {
 	}
 
 	pub fn new(self) -> Transaction {
-		let insertion_id = {
-			let id = self.insertion_id.get() + 1;
-			self.insertion_id.set(id);
-			id
-		};
 		let hash = self.nonce ^ (U256::from(100) * self.gas_price) ^ (U256::from(100_000) * U256::from(self.sender.low_u64()));
 		Transaction {
 			hash: hash.into(),
@@ -67,7 +58,6 @@ impl TransactionBuilder {
 			gas_price: self.gas_price,
 			gas: 21_000.into(),
 			sender: self.sender,
-			insertion_id,
 			mem_usage: self.mem_usage,
 		}
 	}
diff --git a/transaction-pool/src/transactions.rs b/transaction-pool/src/transactions.rs
index c839d9e68..f1a91ff4f 100644
--- a/transaction-pool/src/transactions.rs
+++ b/transaction-pool/src/transactions.rs
@@ -15,28 +15,28 @@
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
 use std::{fmt, mem};
-use std::sync::Arc;
 
 use smallvec::SmallVec;
 
 use ready::{Ready, Readiness};
 use scoring::{self, Scoring};
+use pool::Transaction;
 
 #[derive(Debug)]
 pub enum AddResult<T, S> {
-	Ok(Arc<T>),
+	Ok(T),
 	TooCheapToEnter(T, S),
 	TooCheap {
-		old: Arc<T>,
+		old: T,
 		new: T,
 	},
 	Replaced {
-		old: Arc<T>,
-		new: Arc<T>,
+		old: T,
+		new: T,
 	},
 	PushedOut {
-		old: Arc<T>,
-		new: Arc<T>,
+		old: T,
+		new: T,
 	},
 }
 
@@ -45,7 +45,7 @@ const PER_SENDER: usize = 8;
 #[derive(Debug)]
 pub struct Transactions<T, S: Scoring<T>> {
 	// TODO [ToDr] Consider using something that doesn't require shifting all records.
-	transactions: SmallVec<[Arc<T>; PER_SENDER]>,
+	transactions: SmallVec<[Transaction<T>; PER_SENDER]>,
 	scores: SmallVec<[S::Score; PER_SENDER]>,
 }
 
@@ -67,11 +67,11 @@ impl<T: fmt::Debug, S: Scoring<T>> Transactions<T, S> {
 		self.transactions.len()
 	}
 
-	pub fn iter(&self) -> ::std::slice::Iter<Arc<T>> {
+	pub fn iter(&self) -> ::std::slice::Iter<Transaction<T>> {
 		self.transactions.iter()
 	}
 
-	pub fn worst_and_best(&self) -> Option<((S::Score, Arc<T>), (S::Score, Arc<T>))> {
+	pub fn worst_and_best(&self) -> Option<((S::Score, Transaction<T>), (S::Score, Transaction<T>))> {
 		let len = self.scores.len();
 		self.scores.get(0).cloned().map(|best| {
 			let worst = self.scores[len - 1].clone();
@@ -82,7 +82,7 @@ impl<T: fmt::Debug, S: Scoring<T>> Transactions<T, S> {
 		})
 	}
 
-	pub fn find_next(&self, tx: &T, scoring: &S) -> Option<(S::Score, Arc<T>)> {
+	pub fn find_next(&self, tx: &T, scoring: &S) -> Option<(S::Score, Transaction<T>)> {
 		self.transactions.binary_search_by(|old| scoring.compare(old, &tx)).ok().and_then(|index| {
 			let index = index + 1;
 			if index < self.scores.len() {
@@ -93,18 +93,17 @@ impl<T: fmt::Debug, S: Scoring<T>> Transactions<T, S> {
 		})
 	}
 
-	fn push_cheapest_transaction(&mut self, tx: T, scoring: &S, max_count: usize) -> AddResult<T, S::Score> {
+	fn push_cheapest_transaction(&mut self, tx: Transaction<T>, scoring: &S, max_count: usize) -> AddResult<Transaction<T>, S::Score> {
 		let index = self.transactions.len();
 		if index == max_count {
 			let min_score = self.scores[index - 1].clone();
 			AddResult::TooCheapToEnter(tx, min_score)
 		} else {
-			let shared = Arc::new(tx);
-			self.transactions.push(shared.clone());
+			self.transactions.push(tx.clone());
 			self.scores.push(Default::default());
 			scoring.update_scores(&self.transactions, &mut self.scores, scoring::Change::InsertedAt(index));
 
-			AddResult::Ok(shared)
+			AddResult::Ok(tx)
 		}
 	}
 
@@ -112,28 +111,26 @@ impl<T: fmt::Debug, S: Scoring<T>> Transactions<T, S> {
 		scoring.update_scores(&self.transactions, &mut self.scores, scoring::Change::Event(event));
 	}
 
-	pub fn add(&mut self, tx: T, scoring: &S, max_count: usize) -> AddResult<T, S::Score> {
-		let index = match self.transactions.binary_search_by(|old| scoring.compare(old, &tx)) {
+	pub fn add(&mut self, new: Transaction<T>, scoring: &S, max_count: usize) -> AddResult<Transaction<T>, S::Score> {
+		let index = match self.transactions.binary_search_by(|old| scoring.compare(old, &new)) {
 			Ok(index) => index,
 			Err(index) => index,
 		};
 
 		// Insert at the end.
 		if index == self.transactions.len() {
-			return self.push_cheapest_transaction(tx, scoring, max_count)
+			return self.push_cheapest_transaction(new, scoring, max_count)
 		}
 
 		// Decide if the transaction should replace some other.
-		match scoring.choose(&self.transactions[index], &tx) {
+		match scoring.choose(&self.transactions[index], &new) {
 			// New transaction should be rejected
 			scoring::Choice::RejectNew => AddResult::TooCheap {
 				old: self.transactions[index].clone(),
-				new: tx,
+				new,
 			},
 			// New transaction should be kept along with old ones.
 			scoring::Choice::InsertNew => {
-				let new = Arc::new(tx);
-
 				self.transactions.insert(index, new.clone());
 				self.scores.insert(index, Default::default());
 				scoring.update_scores(&self.transactions, &mut self.scores, scoring::Change::InsertedAt(index));
@@ -153,7 +150,6 @@ impl<T: fmt::Debug, S: Scoring<T>> Transactions<T, S> {
 			},
 			// New transaction is replacing some other transaction already in the queue.
 			scoring::Choice::ReplaceOld => {
-				let new = Arc::new(tx);
 				let old = mem::replace(&mut self.transactions[index], new.clone());
 				scoring.update_scores(&self.transactions, &mut self.scores, scoring::Change::ReplacedAt(index));
 
@@ -181,7 +177,7 @@ impl<T: fmt::Debug, S: Scoring<T>> Transactions<T, S> {
 		return true;
 	}
 
-	pub fn cull<R: Ready<T>>(&mut self, ready: &mut R, scoring: &S) -> SmallVec<[Arc<T>; PER_SENDER]> {
+	pub fn cull<R: Ready<T>>(&mut self, ready: &mut R, scoring: &S) -> SmallVec<[Transaction<T>; PER_SENDER]> {
 		let mut result = SmallVec::new();
 		if self.is_empty() {
 			return result;
@@ -190,7 +186,7 @@ impl<T: fmt::Debug, S: Scoring<T>> Transactions<T, S> {
 		let mut first_non_stalled = 0;
 		for tx in &self.transactions {
 			match ready.is_ready(tx) {
-				Readiness::Stalled => {
+				Readiness::Stale => {
 					first_non_stalled += 1;
 				},
 				Readiness::Ready | Readiness::Future => break,
