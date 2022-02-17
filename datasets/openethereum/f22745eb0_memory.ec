commit f22745eb0a95ff9a2edae65995662b4f95f557a8
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Fri Jun 30 11:57:48 2017 +0200

    TransactionQueue improvements (#5917)
    
    * Order by id instead of hash.
    
    * Minimal gas price bump.
    
    * Avoid to construct oversized transaction packets.
    
    * Fix RPC.
    
    * Never construct oversized transactions packet.
    
    * Never construct oversized packets.

diff --git a/ethcore/src/miner/transaction_queue.rs b/ethcore/src/miner/transaction_queue.rs
index 59ab3eacf..d833f8f6a 100644
--- a/ethcore/src/miner/transaction_queue.rs
+++ b/ethcore/src/miner/transaction_queue.rs
@@ -165,7 +165,7 @@ struct TransactionOrder {
 	/// Gas usage priority factor. Usage depends on strategy.
 	/// Represents the linear increment in required gas price for heavy transactions.
 	///
-	/// High gas limit + Low gas price = Low priority
+	/// High gas limit + Low gas price = Very Low priority
 	/// High gas limit + High gas price = High priority
 	gas_factor: U256,
 	/// Gas (limit) of the transaction. Usage depends on strategy.
@@ -175,6 +175,8 @@ struct TransactionOrder {
 	strategy: PrioritizationStrategy,
 	/// Hash to identify associated transaction
 	hash: H256,
+	/// Incremental id assigned when transaction is inserted to the queue.
+	insertion_id: u64,
 	/// Origin of the transaction
 	origin: TransactionOrigin,
 	/// Penalties
@@ -193,6 +195,7 @@ impl TransactionOrder {
 			gas_factor: factor,
 			strategy: strategy,
 			hash: tx.hash(),
+			insertion_id: tx.insertion_id,
 			origin: tx.origin,
 			penalties: 0,
 		}
@@ -262,8 +265,8 @@ impl Ord for TransactionOrder {
 			return b.gas_price.cmp(&self.gas_price);
 		}
 
-		// Compare hashes
-		self.hash.cmp(&b.hash)
+		// Lastly compare insertion_id
+		self.insertion_id.cmp(&b.insertion_id)
 	}
 }
 
@@ -274,19 +277,28 @@ struct VerifiedTransaction {
 	transaction: SignedTransaction,
 	/// Transaction origin.
 	origin: TransactionOrigin,
-	/// Insertion time
-	insertion_time: QueuingInstant,
 	/// Delay until specified condition is met.
 	condition: Option<Condition>,
+	/// Insertion time
+	insertion_time: QueuingInstant,
+	/// ID assigned upon insertion, should be unique.
+	insertion_id: u64,
 }
 
 impl VerifiedTransaction {
-	fn new(transaction: SignedTransaction, origin: TransactionOrigin, time: QueuingInstant, condition: Option<Condition>) -> Self {
+	fn new(
+		transaction: SignedTransaction,
+		origin: TransactionOrigin,
+		condition: Option<Condition>,
+		insertion_time: QueuingInstant,
+		insertion_id: u64,
+	) -> Self {
 		VerifiedTransaction {
-			transaction: transaction,
-			origin: origin,
-			insertion_time: time,
-			condition: condition,
+			transaction,
+			origin,
+			condition,
+			insertion_time,
+			insertion_id,
 		}
 	}
 
@@ -486,6 +498,9 @@ pub struct AccountDetails {
 
 /// Transactions with `gas > (gas_limit + gas_limit * Factor(in percents))` are not imported to the queue.
 const GAS_LIMIT_HYSTERESIS: usize = 200; // (100/GAS_LIMIT_HYSTERESIS) %
+/// Transaction with the same (sender, nonce) can be replaced only if
+/// `new_gas_price > old_gas_price + old_gas_price >> SHIFT`
+const GAS_PRICE_BUMP_SHIFT: usize = 3; // 2 = 25%, 3 = 12.5%, 4 = 6.25%
 
 /// Describes the strategy used to prioritize transactions in the queue.
 #[cfg_attr(feature="dev", allow(enum_variant_names))]
@@ -557,6 +572,8 @@ pub struct TransactionQueue {
 	last_nonces: HashMap<Address, U256>,
 	/// List of local transactions and their statuses.
 	local_transactions: LocalTransactionsList,
+	/// Next id that should be assigned to a transaction imported to the queue.
+	next_transaction_id: u64,
 }
 
 impl Default for TransactionQueue {
@@ -600,6 +617,7 @@ impl TransactionQueue {
 			by_hash: HashMap::new(),
 			last_nonces: HashMap::new(),
 			local_transactions: LocalTransactionsList::default(),
+			next_transaction_id: 0,
 		}
 	}
 
@@ -824,7 +842,9 @@ impl TransactionQueue {
 		}
 		tx.check_low_s()?;
 		// No invalid transactions beyond this point.
-		let vtx = VerifiedTransaction::new(tx, origin, time, condition);
+		let id = self.next_transaction_id;
+		self.next_transaction_id += 1;
+		let vtx = VerifiedTransaction::new(tx, origin, condition, time, id);
 		let r = self.import_tx(vtx, client_account.nonce).map_err(Error::Transaction);
 		assert_eq!(self.future.by_priority.len() + self.current.by_priority.len(), self.by_hash.len());
 		r
@@ -1352,16 +1372,19 @@ impl TransactionQueue {
 		// There was already transaction in queue. Let's check which one should stay
 		let old_hash = old.hash;
 		let new_hash = order.hash;
-		let old_fee = old.gas_price;
-		let new_fee = order.gas_price;
-		if old_fee.cmp(&new_fee) == Ordering::Greater {
+
+		let old_gas_price = old.gas_price;
+		let new_gas_price = order.gas_price;
+		let min_required_gas_price = old_gas_price + (old_gas_price >> GAS_PRICE_BUMP_SHIFT);
+
+		if min_required_gas_price > new_gas_price {
 			trace!(target: "txqueue", "Didn't insert transaction because gas price was too low: {:?} ({:?} stays in the queue)", order.hash, old.hash);
 			// Put back old transaction since it has greater priority (higher gas_price)
 			set.insert(address, nonce, old);
 			// and remove new one
 			let order = by_hash.remove(&order.hash).expect("The hash has been just inserted and no other line is altering `by_hash`.");
 			if order.origin.is_local() {
-				local.mark_replaced(order.transaction, old_fee, old_hash);
+				local.mark_replaced(order.transaction, old_gas_price, old_hash);
 			}
 			false
 		} else {
@@ -1369,7 +1392,7 @@ impl TransactionQueue {
 			// Make sure we remove old transaction entirely
 			let old = by_hash.remove(&old.hash).expect("The hash is coming from `future` so it has to be in `by_hash`.");
 			if old.origin.is_local() {
-				local.mark_replaced(old.transaction, new_fee, new_hash);
+				local.mark_replaced(old.transaction, new_gas_price, new_hash);
 			}
 			true
 		}
@@ -1611,12 +1634,12 @@ pub mod test {
 			gas_limit: !U256::zero(),
 		};
 		let (tx1, tx2) = new_tx_pair_default(1.into(), 0.into());
-		let tx1 = VerifiedTransaction::new(tx1, TransactionOrigin::External, 0, None);
-		let tx2 = VerifiedTransaction::new(tx2, TransactionOrigin::External, 0, None);
+		let tx1 = VerifiedTransaction::new(tx1, TransactionOrigin::External, None, 0, 0);
+		let tx2 = VerifiedTransaction::new(tx2, TransactionOrigin::External, None, 0, 1);
 		let mut by_hash = {
 			let mut x = HashMap::new();
-			let tx1 = VerifiedTransaction::new(tx1.transaction.clone(), TransactionOrigin::External, 0, None);
-			let tx2 = VerifiedTransaction::new(tx2.transaction.clone(), TransactionOrigin::External, 0, None);
+			let tx1 = VerifiedTransaction::new(tx1.transaction.clone(), TransactionOrigin::External, None, 0, 0);
+			let tx2 = VerifiedTransaction::new(tx2.transaction.clone(), TransactionOrigin::External, None, 0, 1);
 			x.insert(tx1.hash(), tx1);
 			x.insert(tx2.hash(), tx2);
 			x
@@ -1654,12 +1677,12 @@ pub mod test {
 		// Create two transactions with same nonce
 		// (same hash)
 		let (tx1, tx2) = new_tx_pair_default(0.into(), 0.into());
-		let tx1 = VerifiedTransaction::new(tx1, TransactionOrigin::External, 0, None);
-		let tx2 = VerifiedTransaction::new(tx2, TransactionOrigin::External, 0, None);
+		let tx1 = VerifiedTransaction::new(tx1, TransactionOrigin::External, None, 0, 0);
+		let tx2 = VerifiedTransaction::new(tx2, TransactionOrigin::External, None, 0, 1);
 		let by_hash = {
 			let mut x = HashMap::new();
-			let tx1 = VerifiedTransaction::new(tx1.transaction.clone(), TransactionOrigin::External, 0, None);
-			let tx2 = VerifiedTransaction::new(tx2.transaction.clone(), TransactionOrigin::External, 0, None);
+			let tx1 = VerifiedTransaction::new(tx1.transaction.clone(), TransactionOrigin::External, None, 0, 0);
+			let tx2 = VerifiedTransaction::new(tx2.transaction.clone(), TransactionOrigin::External, None, 0, 1);
 			x.insert(tx1.hash(), tx1);
 			x.insert(tx2.hash(), tx2);
 			x
@@ -1701,10 +1724,10 @@ pub mod test {
 			gas_limit: !U256::zero(),
 		};
 		let tx = new_tx_default();
-		let tx1 = VerifiedTransaction::new(tx.clone(), TransactionOrigin::External, 0, None);
+		let tx1 = VerifiedTransaction::new(tx.clone(), TransactionOrigin::External, None, 0, 0);
 		let order1 = TransactionOrder::for_transaction(&tx1, 0.into(), 1.into(), PrioritizationStrategy::GasPriceOnly);
 		assert!(set.insert(tx1.sender(), tx1.nonce(), order1).is_none());
-		let tx2 = VerifiedTransaction::new(tx, TransactionOrigin::External, 0, None);
+		let tx2 = VerifiedTransaction::new(tx, TransactionOrigin::External, None, 0, 1);
 		let order2 = TransactionOrder::for_transaction(&tx2, 0.into(), 1.into(), PrioritizationStrategy::GasPriceOnly);
 		assert!(set.insert(tx2.sender(), tx2.nonce(), order2).is_some());
 	}
@@ -1721,7 +1744,7 @@ pub mod test {
 
 		assert_eq!(set.gas_price_entry_limit(), 0.into());
 		let tx = new_tx_default();
-		let tx1 = VerifiedTransaction::new(tx.clone(), TransactionOrigin::External, 0, None);
+		let tx1 = VerifiedTransaction::new(tx.clone(), TransactionOrigin::External, None, 0, 0);
 		let order1 = TransactionOrder::for_transaction(&tx1, 0.into(), 1.into(), PrioritizationStrategy::GasPriceOnly);
 		assert!(set.insert(tx1.sender(), tx1.nonce(), order1.clone()).is_none());
 		assert_eq!(set.gas_price_entry_limit(), 2.into());
@@ -2473,6 +2496,32 @@ pub mod test {
 		assert_eq!(stats.pending, 2);
 	}
 
+	#[test]
+	fn should_not_replace_same_transaction_if_the_fee_is_less_than_minimal_bump() {
+		use ethcore_logger::init_log;
+		init_log();
+		// given
+		let mut txq = TransactionQueue::default();
+		let keypair = Random.generate().unwrap();
+		let tx = new_unsigned_tx(123.into(), default_gas_val(), 20.into()).sign(keypair.secret(), None);
+		let tx2 = {
+			let mut tx2 = (**tx).clone();
+			tx2.gas_price = U256::from(21);
+			tx2.sign(keypair.secret(), None)
+		};
+
+		// when
+		txq.add(tx, TransactionOrigin::External, 0, None, &default_tx_provider()).unwrap();
+		let res = txq.add(tx2, TransactionOrigin::External, 0, None, &default_tx_provider());
+
+		// then
+		assert_eq!(unwrap_tx_err(res), TransactionError::TooCheapToReplace);
+		let stats = txq.status();
+		assert_eq!(stats.pending, 1);
+		assert_eq!(stats.future, 0);
+		assert_eq!(txq.top_transactions()[0].gas_price, U256::from(20));
+	}
+
 	#[test]
 	fn should_replace_same_transaction_when_has_higher_fee() {
 		use ethcore_logger::init_log;
@@ -2480,10 +2529,10 @@ pub mod test {
 		// given
 		let mut txq = TransactionQueue::default();
 		let keypair = Random.generate().unwrap();
-		let tx = new_unsigned_tx(123.into(), default_gas_val(), 1.into()).sign(keypair.secret(), None);
+		let tx = new_unsigned_tx(123.into(), default_gas_val(), 10.into()).sign(keypair.secret(), None);
 		let tx2 = {
 			let mut tx2 = (**tx).clone();
-			tx2.gas_price = U256::from(200);
+			tx2.gas_price = U256::from(20);
 			tx2.sign(keypair.secret(), None)
 		};
 
@@ -2495,7 +2544,7 @@ pub mod test {
 		let stats = txq.status();
 		assert_eq!(stats.pending, 1);
 		assert_eq!(stats.future, 0);
-		assert_eq!(txq.top_transactions()[0].gas_price, U256::from(200));
+		assert_eq!(txq.top_transactions()[0].gas_price, U256::from(20));
 	}
 
 	#[test]
@@ -2815,6 +2864,24 @@ pub mod test {
 		assert_eq!(txq.top_transactions().len(), 1);
 	}
 
+	#[test]
+	fn should_not_order_transactions_by_hash() {
+		// given
+		let secret1 = "0000000000000000000000000000000000000000000000000000000000000002".parse().unwrap();
+		let secret2 = "0000000000000000000000000000000000000000000000000000000000000001".parse().unwrap();
+		let tx1 = new_unsigned_tx(123.into(), default_gas_val(), 0.into()).sign(&secret1, None);
+		let tx2 = new_unsigned_tx(123.into(), default_gas_val(), 0.into()).sign(&secret2, None);
+		let mut txq = TransactionQueue::default();
+
+		// when
+		txq.add(tx1.clone(), TransactionOrigin::External, 0, None, &default_tx_provider()).unwrap();
+		txq.add(tx2, TransactionOrigin::External, 0, None, &default_tx_provider()).unwrap();
+
+		// then
+		assert_eq!(txq.top_transactions()[0], tx1);
+		assert_eq!(txq.top_transactions().len(), 2);
+	}
+
 	#[test]
 	fn should_not_return_transactions_over_nonce_cap() {
 		// given
diff --git a/sync/src/chain.rs b/sync/src/chain.rs
index badd784a4..1b31f9169 100644
--- a/sync/src/chain.rs
+++ b/sync/src/chain.rs
@@ -126,6 +126,8 @@ const MAX_NEW_HASHES: usize = 64;
 const MAX_TX_TO_IMPORT: usize = 512;
 const MAX_NEW_BLOCK_AGE: BlockNumber = 20;
 const MAX_TRANSACTION_SIZE: usize = 300*1024;
+// maximal packet size with transactions (cannot be greater than 16MB - protocol limitation).
+const MAX_TRANSACTION_PACKET_SIZE: usize = 8 * 1024 * 1024;
 // Maximal number of transactions in sent in single packet.
 const MAX_TRANSACTIONS_TO_PROPAGATE: usize = 64;
 // Min number of blocks to be behind for a snapshot sync
@@ -2044,7 +2046,7 @@ impl ChainSync {
 						// update stats
 						for hash in &all_transactions_hashes {
 							let id = io.peer_session_info(peer_id).and_then(|info| info.id);
-							stats.propagated(*hash, id, block_number);
+							stats.propagated(hash, id, block_number);
 						}
 						peer_info.last_sent_transactions = all_transactions_hashes.clone();
 						return Some((peer_id, all_transactions_hashes.len(), all_transactions_rlp.clone()));
@@ -2060,14 +2062,35 @@ impl ChainSync {
 					}
 
 					// Construct RLP
-					let mut packet = RlpStream::new_list(to_send.len());
-					for tx in &transactions {
-						if to_send.contains(&tx.transaction.hash()) {
-							packet.append(&tx.transaction);
-							// update stats
-							let id = io.peer_session_info(peer_id).and_then(|info| info.id);
-							stats.propagated(tx.transaction.hash(), id, block_number);
+					let (packet, to_send) = {
+						let mut to_send = to_send;
+						let mut packet = RlpStream::new();
+						packet.begin_unbounded_list();
+						let mut pushed = 0;
+						for tx in &transactions {
+							let hash = tx.transaction.hash();
+							if to_send.contains(&hash) {
+								let mut transaction = RlpStream::new();
+								tx.transaction.rlp_append(&mut transaction);
+								let appended = packet.append_raw_checked(&transaction.drain(), 1, MAX_TRANSACTION_PACKET_SIZE);
+								if !appended {
+									// Maximal packet size reached just proceed with sending
+									debug!("Transaction packet size limit reached. Sending incomplete set of {}/{} transactions.", pushed, to_send.len());
+									to_send = to_send.into_iter().take(pushed).collect();
+									break;
+								}
+								pushed += 1;
+							}
 						}
+						packet.complete_unbounded_list();
+						(packet, to_send)
+					};
+
+					// Update stats
+					let id = io.peer_session_info(peer_id).and_then(|info| info.id);
+					for hash in &to_send {
+						// update stats
+						stats.propagated(hash, id, block_number);
 					}
 
 					peer_info.last_sent_transactions = all_transactions_hashes
diff --git a/sync/src/transactions_stats.rs b/sync/src/transactions_stats.rs
index 480b9bfe8..dcd2702c8 100644
--- a/sync/src/transactions_stats.rs
+++ b/sync/src/transactions_stats.rs
@@ -56,9 +56,9 @@ pub struct TransactionsStats {
 
 impl TransactionsStats {
 	/// Increases number of propagations to given `enodeid`.
-	pub fn propagated(&mut self, hash: H256, enode_id: Option<NodeId>, current_block_num: BlockNumber) {
+	pub fn propagated(&mut self, hash: &H256, enode_id: Option<NodeId>, current_block_num: BlockNumber) {
 		let enode_id = enode_id.unwrap_or_default();
-		let mut stats = self.pending_transactions.entry(hash).or_insert_with(|| Stats::new(current_block_num));
+		let mut stats = self.pending_transactions.entry(*hash).or_insert_with(|| Stats::new(current_block_num));
 		let mut count = stats.propagated_to.entry(enode_id).or_insert(0);
 		*count = count.saturating_add(1);
 	}
@@ -101,9 +101,9 @@ mod tests {
 		let enodeid2 = 5.into();
 
 		// when
-		stats.propagated(hash, Some(enodeid1), 5);
-		stats.propagated(hash, Some(enodeid1), 10);
-		stats.propagated(hash, Some(enodeid2), 15);
+		stats.propagated(&hash, Some(enodeid1), 5);
+		stats.propagated(&hash, Some(enodeid1), 10);
+		stats.propagated(&hash, Some(enodeid2), 15);
 
 		// then
 		let stats = stats.get(&hash);
@@ -122,7 +122,7 @@ mod tests {
 		let mut stats = TransactionsStats::default();
 		let hash = 5.into();
 		let enodeid1 = 5.into();
-		stats.propagated(hash, Some(enodeid1), 10);
+		stats.propagated(&hash, Some(enodeid1), 10);
 
 		// when
 		stats.retain(&HashSet::new());
