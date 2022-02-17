commit 0109e5e9d4fa1110b59d907b32a158cd3b3d5762
Author: Tomasz Drwięga <tomasz@ethcore.io>
Date:   Sat Mar 5 13:03:34 2016 +0100

    Removing memory leak when transactions are dropped from set

diff --git a/sync/src/transaction_queue.rs b/sync/src/transaction_queue.rs
index 83665dfda..7f9f21638 100644
--- a/sync/src/transaction_queue.rs
+++ b/sync/src/transaction_queue.rs
@@ -113,22 +113,24 @@ impl TransactionSet {
 		self.by_address.insert(sender, nonce, order);
 	}
 
-	fn enforce_limit(&mut self, by_hash: &HashMap<H256, VerifiedTransaction>) {
+	fn enforce_limit(&mut self, by_hash: &mut HashMap<H256, VerifiedTransaction>) {
 		let len = self.by_priority.len();
 		if len <= self.limit {
 			return;
 		}
 
-		let to_drop : Vec<&VerifiedTransaction> = {
+		let to_drop : Vec<(Address, U256)> = {
 			self.by_priority
 				.iter()
 				.skip(self.limit)
 				.map(|order| by_hash.get(&order.hash).expect("Inconsistency in queue detected."))
+				.map(|tx| (tx.sender(), tx.nonce()))
 				.collect()
 		};
 
-		for tx in to_drop {
-			self.drop(&tx.sender(), &tx.nonce());
+		for (sender, nonce) in to_drop {
+			let order = self.drop(&sender, &nonce).expect("Droping transaction failed.");
+			by_hash.remove(&order.hash).expect("Inconsistency in queue.");
 		}
 	}
 
@@ -270,7 +272,7 @@ impl TransactionQueue {
 				self.by_hash.remove(&order.hash);
 			}
 		}
-		self.future.enforce_limit(&self.by_hash);
+		self.future.enforce_limit(&mut self.by_hash);
 
 		// And now lets check if there is some chain of transactions in future
 		// that should be placed in current
@@ -335,7 +337,7 @@ impl TransactionQueue {
 			self.by_hash.insert(tx.hash(), tx);
 			// We have a gap - put to future
 			self.future.insert(address, nonce, order);
-			self.future.enforce_limit(&self.by_hash);
+			self.future.enforce_limit(&mut self.by_hash);
 			return;
 		} else if next_nonce > nonce {
 			// Droping transaction
@@ -354,7 +356,7 @@ impl TransactionQueue {
 		let new_last_nonce = self.move_future_txs(address.clone(), nonce + U256::one(), base_nonce);
 		self.last_nonces.insert(address.clone(), new_last_nonce.unwrap_or(nonce));
 		// Enforce limit
-		self.current.enforce_limit(&self.by_hash);
+		self.current.enforce_limit(&mut self.by_hash);
 	}
 }
 
@@ -413,7 +415,7 @@ mod test {
 		let (tx1, tx2) = new_txs(U256::from(1));
 		let tx1 = VerifiedTransaction::new(tx1);
 		let tx2 = VerifiedTransaction::new(tx2);
-		let by_hash = {
+		let mut by_hash = {
 			let mut x = HashMap::new();
 			let tx1 = VerifiedTransaction::new(tx1.transaction.clone());
 			let tx2 = VerifiedTransaction::new(tx2.transaction.clone());
@@ -430,9 +432,10 @@ mod test {
 		assert_eq!(set.by_address.len(), 2);
 
 		// when
-		set.enforce_limit(&by_hash);
+		set.enforce_limit(&mut by_hash);
 
 		// then
+		assert_eq!(by_hash.len(), 1);
 		assert_eq!(set.by_priority.len(), 1);
 		assert_eq!(set.by_address.len(), 1);
 		assert_eq!(set.by_priority.iter().next().unwrap().clone(), order1);
