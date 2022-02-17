commit 1aaafa2d11b42af6be97754f4bc06e2856904464
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 13 15:12:25 2017 +0200

    Limit transaction queue memory & limit future queue (#6038)
    
    * Remove confusing gas_limit in the pool.
    
    * Change defaults
    
    * Limit transaction queue by memory usage.
    
    * Change defaults to something lower.
    
    * Fix rpc test.
    
    * Fix js issues.
    
    * Renamed block_gas_limit

diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index f037052ce..4b7671946 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -98,6 +98,8 @@ pub struct MinerOptions {
 	pub tx_gas_limit: U256,
 	/// Maximum size of the transaction queue.
 	pub tx_queue_size: usize,
+	/// Maximum memory usage of transactions in the queue (current / future).
+	pub tx_queue_memory_limit: Option<usize>,
 	/// Strategy to use for prioritizing transactions in the queue.
 	pub tx_queue_strategy: PrioritizationStrategy,
 	/// Whether we should fallback to providing all the queue's transactions or just pending.
@@ -123,8 +125,9 @@ impl Default for MinerOptions {
 			reseal_on_own_tx: true,
 			reseal_on_uncle: false,
 			tx_gas_limit: !U256::zero(),
-			tx_queue_size: 1024,
-			tx_queue_gas_limit: GasLimit::Auto,
+			tx_queue_size: 8192,
+			tx_queue_memory_limit: Some(2 * 1024 * 1024),
+			tx_queue_gas_limit: GasLimit::None,
 			tx_queue_strategy: PrioritizationStrategy::GasPriceOnly,
 			pending_set: PendingSet::AlwaysQueue,
 			reseal_min_period: Duration::from_secs(2),
@@ -252,8 +255,15 @@ impl Miner {
 			GasLimit::Fixed(ref limit) => *limit,
 			_ => !U256::zero(),
 		};
-
-		let txq = TransactionQueue::with_limits(options.tx_queue_strategy, options.tx_queue_size, gas_limit, options.tx_gas_limit);
+		let mem_limit = options.tx_queue_memory_limit.unwrap_or_else(usize::max_value);
+
+		let txq = TransactionQueue::with_limits(
+			options.tx_queue_strategy,
+			options.tx_queue_size,
+			mem_limit,
+			gas_limit,
+			options.tx_gas_limit
+		);
 		let txq = match options.tx_queue_banning {
 			Banning::Disabled => BanningTransactionQueue::new(txq, Threshold::NeverBan, Duration::from_secs(180)),
 			Banning::Enabled { ban_duration, min_offends, .. } => BanningTransactionQueue::new(
@@ -1328,6 +1338,7 @@ mod tests {
 				reseal_max_period: Duration::from_secs(120),
 				tx_gas_limit: !U256::zero(),
 				tx_queue_size: 1024,
+				tx_queue_memory_limit: None,
 				tx_queue_gas_limit: GasLimit::None,
 				tx_queue_strategy: PrioritizationStrategy::GasFactorAndGasPrice,
 				pending_set: PendingSet::AlwaysSealing,
diff --git a/ethcore/src/miner/transaction_queue.rs b/ethcore/src/miner/transaction_queue.rs
index 8da9f7150..542b42b93 100644
--- a/ethcore/src/miner/transaction_queue.rs
+++ b/ethcore/src/miner/transaction_queue.rs
@@ -105,7 +105,7 @@ use std::cmp::Ordering;
 use std::cmp;
 use std::collections::{HashSet, HashMap, BTreeSet, BTreeMap};
 use linked_hash_map::LinkedHashMap;
-use util::{Address, H256, U256};
+use util::{Address, H256, U256, HeapSizeOf};
 use util::table::Table;
 use transaction::*;
 use error::{Error, TransactionError};
@@ -171,6 +171,8 @@ struct TransactionOrder {
 	/// Gas (limit) of the transaction. Usage depends on strategy.
 	/// Low gas limit = High priority (processed earlier)
 	gas: U256,
+	/// Heap usage of this transaction.
+	mem_usage: usize,
 	/// Transaction ordering strategy
 	strategy: PrioritizationStrategy,
 	/// Hash to identify associated transaction
@@ -191,8 +193,9 @@ impl TransactionOrder {
 		TransactionOrder {
 			nonce_height: tx.nonce() - base_nonce,
 			gas_price: tx.transaction.gas_price,
-			gas: tx.transaction.gas,
 			gas_factor: factor,
+			gas: tx.transaction.gas,
+			mem_usage: tx.transaction.heap_size_of_children(),
 			strategy: strategy,
 			hash: tx.hash(),
 			insertion_id: tx.insertion_id,
@@ -370,7 +373,8 @@ struct TransactionSet {
 	by_address: Table<Address, U256, TransactionOrder>,
 	by_gas_price: GasPriceQueue,
 	limit: usize,
-	gas_limit: U256,
+	total_gas_limit: U256,
+	memory_limit: usize,
 }
 
 impl TransactionSet {
@@ -402,18 +406,24 @@ impl TransactionSet {
 	/// Returns addresses and lowest nonces of transactions removed because of limit.
 	fn enforce_limit(&mut self, by_hash: &mut HashMap<H256, VerifiedTransaction>, local: &mut LocalTransactionsList) -> Option<HashMap<Address, U256>> {
 		let mut count = 0;
+		let mut mem_usage = 0;
 		let mut gas: U256 = 0.into();
 		let to_drop : Vec<(Address, U256)> = {
 			self.by_priority
 				.iter()
 				.filter(|order| {
-					count = count + 1;
+					// update transaction count and mem usage
+					count += 1;
+					mem_usage += order.mem_usage;
+
+					// calculate current gas usage
 					let r = gas.overflowing_add(order.gas);
 					if r.1 { return false }
 					gas = r.0;
+
+					let is_own_or_retracted = order.origin.is_local() || order.origin == TransactionOrigin::RetractedBlock;
 					// Own and retracted transactions are allowed to go above all limits.
-					order.origin != TransactionOrigin::Local && order.origin != TransactionOrigin::RetractedBlock &&
-					(gas > self.gas_limit || count > self.limit)
+					!is_own_or_retracted && (mem_usage > self.memory_limit || count > self.limit || gas > self.total_gas_limit)
 				})
 				.map(|order| by_hash.get(&order.hash)
 					.expect("All transactions in `self.by_priority` and `self.by_address` are kept in sync with `by_hash`."))
@@ -502,6 +512,10 @@ const GAS_LIMIT_HYSTERESIS: usize = 200; // (100/GAS_LIMIT_HYSTERESIS) %
 /// `new_gas_price > old_gas_price + old_gas_price >> SHIFT`
 const GAS_PRICE_BUMP_SHIFT: usize = 3; // 2 = 25%, 3 = 12.5%, 4 = 6.25%
 
+/// Future queue limits are lower from current queue limits:
+/// `future_limit = current_limit >> SHIFT`
+const FUTURE_QUEUE_LIMITS_SHIFT: usize = 3; // 2 = 25%, 3 = 12.5%, 4 = 6.25%
+
 /// Describes the strategy used to prioritize transactions in the queue.
 #[cfg_attr(feature="dev", allow(enum_variant_names))]
 #[derive(Debug, Copy, Clone, PartialEq, Eq)]
@@ -557,7 +571,7 @@ pub struct TransactionQueue {
 	/// The maximum amount of gas any individual transaction may use.
 	tx_gas_limit: U256,
 	/// Current gas limit (block gas limit * factor). Transactions above the limit will not be accepted (default to !0)
-	gas_limit: U256,
+	total_gas_limit: U256,
 	/// Maximal time transaction may occupy the queue.
 	/// When we reach `max_time_in_queue / 2^3` we re-validate
 	/// account balance.
@@ -585,35 +599,43 @@ impl Default for TransactionQueue {
 impl TransactionQueue {
 	/// Creates new instance of this Queue
 	pub fn new(strategy: PrioritizationStrategy) -> Self {
-		Self::with_limits(strategy, 1024, !U256::zero(), !U256::zero())
+		Self::with_limits(strategy, 8192, usize::max_value(), !U256::zero(), !U256::zero())
 	}
 
 	/// Create new instance of this Queue with specified limits
-	pub fn with_limits(strategy: PrioritizationStrategy, limit: usize, gas_limit: U256, tx_gas_limit: U256) -> Self {
+	pub fn with_limits(
+		strategy: PrioritizationStrategy,
+		limit: usize,
+		memory_limit: usize,
+		total_gas_limit: U256,
+		tx_gas_limit: U256,
+	) -> Self {
 		let current = TransactionSet {
 			by_priority: BTreeSet::new(),
 			by_address: Table::new(),
 			by_gas_price: Default::default(),
-			limit: limit,
-			gas_limit: gas_limit,
+			limit,
+			total_gas_limit,
+			memory_limit,
 		};
 
 		let future = TransactionSet {
 			by_priority: BTreeSet::new(),
 			by_address: Table::new(),
 			by_gas_price: Default::default(),
-			limit: limit,
-			gas_limit: gas_limit,
+			total_gas_limit: total_gas_limit >> FUTURE_QUEUE_LIMITS_SHIFT,
+			limit: limit >> FUTURE_QUEUE_LIMITS_SHIFT,
+			memory_limit: memory_limit >> FUTURE_QUEUE_LIMITS_SHIFT,
 		};
 
 		TransactionQueue {
-			strategy: strategy,
+			strategy,
 			minimal_gas_price: U256::zero(),
-			tx_gas_limit: tx_gas_limit,
-			gas_limit: !U256::zero(),
+			total_gas_limit: !U256::zero(),
+			tx_gas_limit,
 			max_time_in_queue: DEFAULT_QUEUING_PERIOD,
-			current: current,
-			future: future,
+			current,
+			future,
 			by_hash: HashMap::new(),
 			last_nonces: HashMap::new(),
 			local_transactions: LocalTransactionsList::default(),
@@ -624,7 +646,7 @@ impl TransactionQueue {
 	/// Set the new limit for `current` and `future` queue.
 	pub fn set_limit(&mut self, limit: usize) {
 		self.current.set_limit(limit);
-		self.future.set_limit(limit);
+		self.future.set_limit(limit >> FUTURE_QUEUE_LIMITS_SHIFT);
 		// And ensure the limits
 		self.current.enforce_limit(&mut self.by_hash, &mut self.local_transactions);
 		self.future.enforce_limit(&mut self.by_hash, &mut self.local_transactions);
@@ -657,16 +679,17 @@ impl TransactionQueue {
 	pub fn set_gas_limit(&mut self, gas_limit: U256) {
 		let extra = gas_limit / U256::from(GAS_LIMIT_HYSTERESIS);
 
-		self.gas_limit = match gas_limit.overflowing_add(extra) {
+		let total_gas_limit = match gas_limit.overflowing_add(extra) {
 			(_, true) => !U256::zero(),
 			(val, false) => val,
 		};
+		self.total_gas_limit = total_gas_limit;
 	}
 
 	/// Sets new total gas limit.
-	pub fn set_total_gas_limit(&mut self, gas_limit: U256) {
-		self.future.gas_limit = gas_limit;
-		self.current.gas_limit = gas_limit;
+	pub fn set_total_gas_limit(&mut self, total_gas_limit: U256) {
+		self.current.total_gas_limit = total_gas_limit;
+		self.future.total_gas_limit = total_gas_limit >> FUTURE_QUEUE_LIMITS_SHIFT;
 		self.future.enforce_limit(&mut self.by_hash, &mut self.local_transactions);
 	}
 
@@ -796,16 +819,17 @@ impl TransactionQueue {
 			}));
 		}
 
-		if tx.gas > self.gas_limit || tx.gas > self.tx_gas_limit {
+		let gas_limit = cmp::min(self.tx_gas_limit, self.total_gas_limit);
+		if tx.gas > gas_limit {
 			trace!(target: "txqueue",
 				"Dropping transaction above gas limit: {:?} ({} > min({}, {}))",
 				tx.hash(),
 				tx.gas,
-				self.gas_limit,
+				self.total_gas_limit,
 				self.tx_gas_limit
 			);
 			return Err(Error::Transaction(TransactionError::GasLimitExceeded {
-				limit: self.gas_limit,
+				limit: gas_limit,
 				got: tx.gas,
 			}));
 		}
@@ -1591,7 +1615,13 @@ pub mod test {
 	#[test]
 	fn should_return_correct_nonces_when_dropped_because_of_limit() {
 		// given
-		let mut txq = TransactionQueue::with_limits(PrioritizationStrategy::GasPriceOnly, 2, !U256::zero(), !U256::zero());
+		let mut txq = TransactionQueue::with_limits(
+			PrioritizationStrategy::GasPriceOnly,
+			2,
+			usize::max_value(),
+			!U256::zero(),
+			!U256::zero(),
+		);
 		let (tx1, tx2) = new_tx_pair(123.into(), 1.into(), 1.into(), 0.into());
 		let sender = tx1.sender();
 		let nonce = tx1.nonce;
@@ -1631,7 +1661,8 @@ pub mod test {
 			by_address: Table::new(),
 			by_gas_price: Default::default(),
 			limit: 1,
-			gas_limit: !U256::zero(),
+			total_gas_limit: !U256::zero(),
+			memory_limit: usize::max_value(),
 		};
 		let (tx1, tx2) = new_tx_pair_default(1.into(), 0.into());
 		let tx1 = VerifiedTransaction::new(tx1, TransactionOrigin::External, None, 0, 0);
@@ -1672,7 +1703,8 @@ pub mod test {
 			by_address: Table::new(),
 			by_gas_price: Default::default(),
 			limit: 1,
-			gas_limit: !U256::zero(),
+			total_gas_limit: !U256::zero(),
+			memory_limit: 0,
 		};
 		// Create two transactions with same nonce
 		// (same hash)
@@ -1721,7 +1753,8 @@ pub mod test {
 			by_address: Table::new(),
 			by_gas_price: Default::default(),
 			limit: 2,
-			gas_limit: !U256::zero(),
+			total_gas_limit: !U256::zero(),
+			memory_limit: 0,
 		};
 		let tx = new_tx_default();
 		let tx1 = VerifiedTransaction::new(tx.clone(), TransactionOrigin::External, None, 0, 0);
@@ -1739,7 +1772,8 @@ pub mod test {
 			by_address: Table::new(),
 			by_gas_price: Default::default(),
 			limit: 1,
-			gas_limit: !U256::zero(),
+			total_gas_limit: !U256::zero(),
+			memory_limit: 0,
 		};
 
 		assert_eq!(set.gas_price_entry_limit(), 0.into());
@@ -1884,17 +1918,17 @@ pub mod test {
 	}
 
 	#[test]
-	fn gas_limit_should_never_overflow() {
+	fn tx_gas_limit_should_never_overflow() {
 		// given
 		let mut txq = TransactionQueue::default();
 		txq.set_gas_limit(U256::zero());
-		assert_eq!(txq.gas_limit, U256::zero());
+		assert_eq!(txq.total_gas_limit, U256::zero());
 
 		// when
 		txq.set_gas_limit(!U256::zero());
 
 		// then
-		assert_eq!(txq.gas_limit, !U256::zero());
+		assert_eq!(txq.total_gas_limit, !U256::zero());
 	}
 
 	#[test]
@@ -2352,7 +2386,13 @@ pub mod test {
 	#[test]
 	fn should_drop_old_transactions_when_hitting_the_limit() {
 		// given
-		let mut txq = TransactionQueue::with_limits(PrioritizationStrategy::GasPriceOnly, 1, !U256::zero(), !U256::zero());
+		let mut txq = TransactionQueue::with_limits(
+			PrioritizationStrategy::GasPriceOnly,
+			1,
+			usize::max_value(),
+			!U256::zero(),
+			!U256::zero()
+		);
 		let (tx, tx2) = new_tx_pair_default(1.into(), 0.into());
 		let sender = tx.sender();
 		let nonce = tx.nonce;
@@ -2373,7 +2413,13 @@ pub mod test {
 
 	#[test]
 	fn should_limit_future_transactions() {
-		let mut txq = TransactionQueue::with_limits(PrioritizationStrategy::GasPriceOnly, 1, !U256::zero(), !U256::zero());
+		let mut txq = TransactionQueue::with_limits(
+			PrioritizationStrategy::GasPriceOnly,
+			1 << FUTURE_QUEUE_LIMITS_SHIFT,
+			usize::max_value(),
+			!U256::zero(),
+			!U256::zero(),
+		);
 		txq.current.set_limit(10);
 		let (tx1, tx2) = new_tx_pair_default(4.into(), 1.into());
 		let (tx3, tx4) = new_tx_pair_default(4.into(), 2.into());
@@ -2392,7 +2438,13 @@ pub mod test {
 
 	#[test]
 	fn should_limit_by_gas() {
-		let mut txq = TransactionQueue::with_limits(PrioritizationStrategy::GasPriceOnly, 100, default_gas_val() * U256::from(2), !U256::zero());
+		let mut txq = TransactionQueue::with_limits(
+			PrioritizationStrategy::GasPriceOnly,
+			100,
+			usize::max_value(),
+			default_gas_val() * U256::from(2),
+			!U256::zero()
+		);
 		let (tx1, tx2) = new_tx_pair_default(U256::from(1), U256::from(1));
 		let (tx3, tx4) = new_tx_pair_default(U256::from(1), U256::from(2));
 		txq.add(tx1.clone(), TransactionOrigin::External, 0, None, &default_tx_provider()).unwrap();
@@ -2405,7 +2457,13 @@ pub mod test {
 
 	#[test]
 	fn should_keep_own_transactions_above_gas_limit() {
-		let mut txq = TransactionQueue::with_limits(PrioritizationStrategy::GasPriceOnly, 100, default_gas_val() * U256::from(2), !U256::zero());
+		let mut txq = TransactionQueue::with_limits(
+			PrioritizationStrategy::GasPriceOnly,
+			100,
+			usize::max_value(),
+			default_gas_val() * U256::from(2),
+			!U256::zero()
+		);
 		let (tx1, tx2) = new_tx_pair_default(U256::from(1), U256::from(1));
 		let (tx3, tx4) = new_tx_pair_default(U256::from(1), U256::from(2));
 		let (tx5, _) = new_tx_pair_default(U256::from(1), U256::from(2));
@@ -2679,7 +2737,13 @@ pub mod test {
 	#[test]
 	fn should_keep_right_order_in_future() {
 		// given
-		let mut txq = TransactionQueue::with_limits(PrioritizationStrategy::GasPriceOnly, 1, !U256::zero(), !U256::zero());
+		let mut txq = TransactionQueue::with_limits(
+			PrioritizationStrategy::GasPriceOnly,
+			1 << FUTURE_QUEUE_LIMITS_SHIFT,
+			usize::max_value(),
+			!U256::zero(),
+			!U256::zero()
+		);
 		let (tx1, tx2) = new_tx_pair_default(1.into(), 0.into());
 		let prev_nonce = default_account_details().nonce - U256::one();
 
diff --git a/parity/cli/config.full.toml b/parity/cli/config.full.toml
index 624c0ccdf..581871997 100644
--- a/parity/cli/config.full.toml
+++ b/parity/cli/config.full.toml
@@ -106,8 +106,8 @@ usd_per_eth = "auto"
 price_update_period = "hourly"
 gas_floor_target = "4700000"
 gas_cap = "6283184"
-tx_queue_size = 1024
-tx_queue_gas = "auto"
+tx_queue_size = 8192
+tx_queue_gas = "off"
 tx_queue_strategy = "gas_factor"
 tx_queue_ban_count = 1
 tx_queue_ban_time = 180 #s
diff --git a/parity/cli/config.toml b/parity/cli/config.toml
index 39e5686f6..0ad9e7753 100644
--- a/parity/cli/config.toml
+++ b/parity/cli/config.toml
@@ -56,8 +56,8 @@ reseal_on_txs = "all"
 reseal_min_period = 4000
 reseal_max_period = 60000
 price_update_period = "hourly"
-tx_queue_size = 1024
-tx_queue_gas = "auto"
+tx_queue_size = 8192
+tx_queue_gas = "off"
 
 [footprint]
 tracing = "on"
diff --git a/parity/cli/mod.rs b/parity/cli/mod.rs
index 08e38bf19..262e054a2 100644
--- a/parity/cli/mod.rs
+++ b/parity/cli/mod.rs
@@ -278,9 +278,11 @@ usage! {
 			or |c: &Config| otry!(c.mining).gas_cap.clone(),
 		flag_extra_data: Option<String> = None,
 			or |c: &Config| otry!(c.mining).extra_data.clone().map(Some),
-		flag_tx_queue_size: usize = 1024usize,
+		flag_tx_queue_size: usize = 8192usize,
 			or |c: &Config| otry!(c.mining).tx_queue_size.clone(),
-		flag_tx_queue_gas: String = "auto",
+		flag_tx_queue_mem_limit: u32 = 2u32,
+			or |c: &Config| otry!(c.mining).tx_queue_mem_limit.clone(),
+		flag_tx_queue_gas: String = "off",
 			or |c: &Config| otry!(c.mining).tx_queue_gas.clone(),
 		flag_tx_queue_strategy: String = "gas_price",
 			or |c: &Config| otry!(c.mining).tx_queue_strategy.clone(),
@@ -546,6 +548,7 @@ struct Mining {
 	gas_cap: Option<String>,
 	extra_data: Option<String>,
 	tx_queue_size: Option<usize>,
+	tx_queue_mem_limit: Option<u32>,
 	tx_queue_gas: Option<String>,
 	tx_queue_strategy: Option<String>,
 	tx_queue_ban_count: Option<u16>,
@@ -809,8 +812,9 @@ mod tests {
 			flag_gas_floor_target: "4700000".into(),
 			flag_gas_cap: "6283184".into(),
 			flag_extra_data: Some("Parity".into()),
-			flag_tx_queue_size: 1024usize,
-			flag_tx_queue_gas: "auto".into(),
+			flag_tx_queue_size: 8192usize,
+			flag_tx_queue_mem_limit: 2u32,
+			flag_tx_queue_gas: "off".into(),
 			flag_tx_queue_strategy: "gas_factor".into(),
 			flag_tx_queue_ban_count: 1u16,
 			flag_tx_queue_ban_time: 180u16,
@@ -1035,8 +1039,9 @@ mod tests {
 				price_update_period: Some("hourly".into()),
 				gas_floor_target: None,
 				gas_cap: None,
-				tx_queue_size: Some(1024),
-				tx_queue_gas: Some("auto".into()),
+				tx_queue_size: Some(8192),
+				tx_queue_mem_limit: None,
+				tx_queue_gas: Some("off".into()),
 				tx_queue_strategy: None,
 				tx_queue_ban_count: None,
 				tx_queue_ban_time: None,
diff --git a/parity/cli/usage.txt b/parity/cli/usage.txt
index e6fd5fdd7..dc4796e05 100644
--- a/parity/cli/usage.txt
+++ b/parity/cli/usage.txt
@@ -311,6 +311,9 @@ Sealing/Mining Options:
                                    block due to transaction volume (default: {flag_gas_cap}).
   --extra-data STRING              Specify a custom extra-data for authored blocks, no
                                    more than 32 characters. (default: {flag_extra_data:?})
+  --tx-queue-mem-limit MB          Maximum amount of memory that can be used by the
+                                   transaction queue. Setting this parameter to 0
+                                   disables limiting (default: {flag_tx_queue_mem_limit}).
   --tx-queue-size LIMIT            Maximum amount of transactions in the queue (waiting
                                    to be included in next block) (default: {flag_tx_queue_size}).
   --tx-queue-gas LIMIT             Maximum amount of total gas for external transactions in
diff --git a/parity/configuration.rs b/parity/configuration.rs
index 5abe23dca..fe397dff5 100644
--- a/parity/configuration.rs
+++ b/parity/configuration.rs
@@ -407,7 +407,6 @@ impl Configuration {
 			extra_data: self.extra_data()?,
 			gas_floor_target: to_u256(&self.args.flag_gas_floor_target)?,
 			gas_ceil_target: to_u256(&self.args.flag_gas_cap)?,
-			transactions_limit: self.args.flag_tx_queue_size,
 			engine_signer: self.engine_signer()?,
 		};
 
@@ -532,6 +531,9 @@ impl Configuration {
 				None => U256::max_value(),
 			},
 			tx_queue_size: self.args.flag_tx_queue_size,
+			tx_queue_memory_limit: if self.args.flag_tx_queue_mem_limit > 0 {
+				Some(self.args.flag_tx_queue_mem_limit as usize * 1024 * 1024)
+			} else { None },
 			tx_queue_gas_limit: to_gas_limit(&self.args.flag_tx_queue_gas)?,
 			tx_queue_strategy: to_queue_strategy(&self.args.flag_tx_queue_strategy)?,
 			pending_set: to_pending_set(&self.args.flag_relay_set)?,
diff --git a/parity/params.rs b/parity/params.rs
index 507d1a9cb..40181f0c0 100644
--- a/parity/params.rs
+++ b/parity/params.rs
@@ -246,7 +246,6 @@ pub struct MinerExtras {
 	pub extra_data: Vec<u8>,
 	pub gas_floor_target: U256,
 	pub gas_ceil_target: U256,
-	pub transactions_limit: usize,
 	pub engine_signer: Address,
 }
 
@@ -257,7 +256,6 @@ impl Default for MinerExtras {
 			extra_data: version_data(),
 			gas_floor_target: U256::from(4_700_000),
 			gas_ceil_target: U256::from(6_283_184),
-			transactions_limit: 1024,
 			engine_signer: Default::default(),
 		}
 	}
diff --git a/parity/run.rs b/parity/run.rs
index 98a595b65..30f4c8759 100644
--- a/parity/run.rs
+++ b/parity/run.rs
@@ -473,7 +473,6 @@ pub fn execute(cmd: RunCmd, can_restart: bool, logger: Arc<RotatingLogger>) -> R
 	miner.set_gas_floor_target(cmd.miner_extras.gas_floor_target);
 	miner.set_gas_ceil_target(cmd.miner_extras.gas_ceil_target);
 	miner.set_extra_data(cmd.miner_extras.extra_data);
-	miner.set_transactions_limit(cmd.miner_extras.transactions_limit);
 	miner.set_minimal_gas_price(initial_min_gas_price);
 	miner.recalibrate_minimal_gas_price();
 	let engine_signer = cmd.miner_extras.engine_signer;
diff --git a/rpc/src/v1/tests/eth.rs b/rpc/src/v1/tests/eth.rs
index 7ce1dcc29..7cd146082 100644
--- a/rpc/src/v1/tests/eth.rs
+++ b/rpc/src/v1/tests/eth.rs
@@ -64,6 +64,7 @@ fn miner_service(spec: &Spec, accounts: Arc<AccountProvider>) -> Arc<Miner> {
 			tx_queue_strategy: PrioritizationStrategy::GasPriceOnly,
 			tx_queue_gas_limit: GasLimit::None,
 			tx_queue_banning: Banning::Disabled,
+			tx_queue_memory_limit: None,
 			pending_set: PendingSet::SealingOrElseQueue,
 			reseal_min_period: Duration::from_secs(0),
 			reseal_max_period: Duration::from_secs(120),
diff --git a/util/src/cache.rs b/util/src/cache.rs
index 79b22f9ae..9d59f2c97 100644
--- a/util/src/cache.rs
+++ b/util/src/cache.rs
@@ -76,4 +76,4 @@ impl<K: Eq + Hash, V: HeapSizeOf> MemoryLruCache<K, V> {
 	pub fn current_size(&self) -> usize {
 		self.cur_size
 	}
-}
\ No newline at end of file
+}
