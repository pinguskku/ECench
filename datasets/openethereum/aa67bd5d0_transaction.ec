commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
commit aa67bd5d00e48bac71ab81a384ac2902757eebed
Author: Tomasz Drwięga <tomusdrw@users.noreply.github.com>
Date:   Thu Jul 5 17:27:48 2018 +0200

    A last bunch of txqueue performance optimizations (#9024)
    
    * Clear cache only when block is enacted.
    
    * Add tracing for cull.
    
    * Cull split.
    
    * Cull after creating pending block.
    
    * Add constant, remove sync::read tracing.
    
    * Reset debug.
    
    * Remove excessive tracing.
    
    * Use struct for NonceCache.
    
    * Fix build
    
    * Remove warnings.
    
    * Fix build again.

diff --git a/ethcore/private-tx/src/lib.rs b/ethcore/private-tx/src/lib.rs
index 968b73be8..2034ea7fa 100644
--- a/ethcore/private-tx/src/lib.rs
+++ b/ethcore/private-tx/src/lib.rs
@@ -83,7 +83,7 @@ use ethcore::client::{
 	Client, ChainNotify, ChainRoute, ChainMessageType, ClientIoMessage, BlockId, CallContract
 };
 use ethcore::account_provider::AccountProvider;
-use ethcore::miner::{self, Miner, MinerService};
+use ethcore::miner::{self, Miner, MinerService, pool_client::NonceCache};
 use ethcore::trace::{Tracer, VMTracer};
 use rustc_hex::FromHex;
 use ethkey::Password;
@@ -96,6 +96,9 @@ use_contract!(private, "PrivateContract", "res/private.json");
 /// Initialization vector length.
 const INIT_VEC_LEN: usize = 16;
 
+/// Size of nonce cache
+const NONCE_CACHE_SIZE: usize = 128;
+
 /// Configurtion for private transaction provider
 #[derive(Default, PartialEq, Debug, Clone)]
 pub struct ProviderConfig {
@@ -245,7 +248,7 @@ impl Provider where {
 		Ok(original_transaction)
 	}
 
-	fn pool_client<'a>(&'a self, nonce_cache: &'a RwLock<HashMap<Address, U256>>) -> miner::pool_client::PoolClient<'a, Client> {
+	fn pool_client<'a>(&'a self, nonce_cache: &'a NonceCache) -> miner::pool_client::PoolClient<'a, Client> {
 		let engine = self.client.engine();
 		let refuse_service_transactions = true;
 		miner::pool_client::PoolClient::new(
@@ -264,7 +267,7 @@ impl Provider where {
 	/// can be replaced with a single `drain()` method instead.
 	/// Thanks to this we also don't really need to lock the entire verification for the time of execution.
 	fn process_queue(&self) -> Result<(), Error> {
-		let nonce_cache = Default::default();
+		let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 		let mut verification_queue = self.transactions_for_verification.lock();
 		let ready_transactions = verification_queue.ready_transactions(self.pool_client(&nonce_cache));
 		for transaction in ready_transactions {
@@ -585,7 +588,7 @@ impl Importer for Arc<Provider> {
 				trace!("Validating transaction: {:?}", original_tx);
 				// Verify with the first account available
 				trace!("The following account will be used for verification: {:?}", validation_account);
-				let nonce_cache = Default::default();
+				let nonce_cache = NonceCache::new(NONCE_CACHE_SIZE);
 				self.transactions_for_verification.lock().add_transaction(
 					original_tx,
 					contract,
diff --git a/ethcore/src/client/config.rs b/ethcore/src/client/config.rs
index 1045ea610..c8b931dee 100644
--- a/ethcore/src/client/config.rs
+++ b/ethcore/src/client/config.rs
@@ -152,7 +152,7 @@ impl Default for ClientConfig {
 }
 #[cfg(test)]
 mod test {
-	use super::{DatabaseCompactionProfile, Mode};
+	use super::{DatabaseCompactionProfile};
 
 	#[test]
 	fn test_default_compaction_profile() {
diff --git a/ethcore/src/miner/miner.rs b/ethcore/src/miner/miner.rs
index 81ace93fe..d196dc2f0 100644
--- a/ethcore/src/miner/miner.rs
+++ b/ethcore/src/miner/miner.rs
@@ -14,8 +14,9 @@
 // You should have received a copy of the GNU General Public License
 // along with Parity.  If not, see <http://www.gnu.org/licenses/>.
 
+use std::cmp;
 use std::time::{Instant, Duration};
-use std::collections::{BTreeMap, BTreeSet, HashSet, HashMap};
+use std::collections::{BTreeMap, BTreeSet, HashSet};
 use std::sync::Arc;
 
 use ansi_term::Colour;
@@ -47,7 +48,7 @@ use client::BlockId;
 use executive::contract_address;
 use header::{Header, BlockNumber};
 use miner;
-use miner::pool_client::{PoolClient, CachedNonceClient};
+use miner::pool_client::{PoolClient, CachedNonceClient, NonceCache};
 use receipt::{Receipt, RichReceipt};
 use spec::Spec;
 use state::State;
@@ -203,7 +204,7 @@ pub struct Miner {
 	params: RwLock<AuthoringParams>,
 	#[cfg(feature = "work-notify")]
 	listeners: RwLock<Vec<Box<NotifyWork>>>,
-	nonce_cache: RwLock<HashMap<Address, U256>>,
+	nonce_cache: NonceCache,
 	gas_pricer: Mutex<GasPricer>,
 	options: MinerOptions,
 	// TODO [ToDr] Arc is only required because of price updater
@@ -230,6 +231,7 @@ impl Miner {
 		let limits = options.pool_limits.clone();
 		let verifier_options = options.pool_verification_options.clone();
 		let tx_queue_strategy = options.tx_queue_strategy;
+		let nonce_cache_size = cmp::max(4096, limits.max_count / 4);
 
 		Miner {
 			sealing: Mutex::new(SealingWork {
@@ -244,7 +246,7 @@ impl Miner {
 			#[cfg(feature = "work-notify")]
 			listeners: RwLock::new(vec![]),
 			gas_pricer: Mutex::new(gas_pricer),
-			nonce_cache: RwLock::new(HashMap::with_capacity(1024)),
+			nonce_cache: NonceCache::new(nonce_cache_size),
 			options,
 			transaction_queue: Arc::new(TransactionQueue::new(limits, verifier_options, tx_queue_strategy)),
 			accounts,
@@ -883,7 +885,7 @@ impl miner::MinerService for Miner {
 		let chain_info = chain.chain_info();
 
 		let from_queue = || self.transaction_queue.pending_hashes(
-			|sender| self.nonce_cache.read().get(sender).cloned(),
+			|sender| self.nonce_cache.get(sender),
 		);
 
 		let from_pending = || {
@@ -1126,14 +1128,15 @@ impl miner::MinerService for Miner {
 
 		if has_new_best_block {
 			// Clear nonce cache
-			self.nonce_cache.write().clear();
+			self.nonce_cache.clear();
 		}
 
 		// First update gas limit in transaction queue and minimal gas price.
 		let gas_limit = *chain.best_block_header().gas_limit();
 		self.update_transaction_queue_limits(gas_limit);
 
-		// Then import all transactions...
+
+		// Then import all transactions from retracted blocks.
 		let client = self.pool_client(chain);
 		{
 			retracted
@@ -1152,11 +1155,6 @@ impl miner::MinerService for Miner {
 				});
 		}
 
-		if has_new_best_block {
-			// ...and at the end remove the old ones
-			self.transaction_queue.cull(client);
-		}
-
 		if has_new_best_block || (imported.len() > 0 && self.options.reseal_on_uncle) {
 			// Reset `next_allowed_reseal` in case a block is imported.
 			// Even if min_period is high, we will always attempt to create
@@ -1171,6 +1169,15 @@ impl miner::MinerService for Miner {
 				self.update_sealing(chain);
 			}
 		}
+
+		if has_new_best_block {
+			// Make sure to cull transactions after we update sealing.
+			// Not culling won't lead to old transactions being added to the block
+			// (thanks to Ready), but culling can take significant amount of time,
+			// so best to leave it after we create some work for miners to prevent increased
+			// uncle rate.
+			self.transaction_queue.cull(client);
+		}
 	}
 
 	fn pending_state(&self, latest_block_number: BlockNumber) -> Option<Self::State> {
diff --git a/ethcore/src/miner/pool_client.rs b/ethcore/src/miner/pool_client.rs
index bcf93d375..f537a2757 100644
--- a/ethcore/src/miner/pool_client.rs
+++ b/ethcore/src/miner/pool_client.rs
@@ -36,10 +36,32 @@ use header::Header;
 use miner;
 use miner::service_transaction_checker::ServiceTransactionChecker;
 
-type NoncesCache = RwLock<HashMap<Address, U256>>;
+/// Cache for state nonces.
+#[derive(Debug)]
+pub struct NonceCache {
+	nonces: RwLock<HashMap<Address, U256>>,
+	limit: usize
+}
+
+impl NonceCache {
+	/// Create new cache with a limit of `limit` entries.
+	pub fn new(limit: usize) -> Self {
+		NonceCache {
+			nonces: RwLock::new(HashMap::with_capacity(limit / 2)),
+			limit,
+		}
+	}
+
+	/// Retrieve a cached nonce for given sender.
+	pub fn get(&self, sender: &Address) -> Option<U256> {
+		self.nonces.read().get(sender).cloned()
+	}
 
-const MAX_NONCE_CACHE_SIZE: usize = 4096;
-const EXPECTED_NONCE_CACHE_SIZE: usize = 2048;
+	/// Clear all entries from the cache.
+	pub fn clear(&self) {
+		self.nonces.write().clear();
+	}
+}
 
 /// Blockchain accesss for transaction pool.
 pub struct PoolClient<'a, C: 'a> {
@@ -70,7 +92,7 @@ C: BlockInfo + CallContract,
 	/// Creates new client given chain, nonce cache, accounts and service transaction verifier.
 	pub fn new(
 		chain: &'a C,
-		cache: &'a NoncesCache,
+		cache: &'a NonceCache,
 		engine: &'a EthEngine,
 		accounts: Option<&'a AccountProvider>,
 		refuse_service_transactions: bool,
@@ -161,7 +183,7 @@ impl<'a, C: 'a> NonceClient for PoolClient<'a, C> where
 
 pub(crate) struct CachedNonceClient<'a, C: 'a> {
 	client: &'a C,
-	cache: &'a NoncesCache,
+	cache: &'a NonceCache,
 }
 
 impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
@@ -176,13 +198,14 @@ impl<'a, C: 'a> Clone for CachedNonceClient<'a, C> {
 impl<'a, C: 'a> fmt::Debug for CachedNonceClient<'a, C> {
 	fn fmt(&self, fmt: &mut fmt::Formatter) -> fmt::Result {
 		fmt.debug_struct("CachedNonceClient")
-			.field("cache", &self.cache.read().len())
+			.field("cache", &self.cache.nonces.read().len())
+			.field("limit", &self.cache.limit)
 			.finish()
 	}
 }
 
 impl<'a, C: 'a> CachedNonceClient<'a, C> {
-	pub fn new(client: &'a C, cache: &'a NoncesCache) -> Self {
+	pub fn new(client: &'a C, cache: &'a NonceCache) -> Self {
 		CachedNonceClient {
 			client,
 			cache,
@@ -194,27 +217,29 @@ impl<'a, C: 'a> NonceClient for CachedNonceClient<'a, C> where
 	C: Nonce + Sync,
 {
   fn account_nonce(&self, address: &Address) -> U256 {
-	  if let Some(nonce) = self.cache.read().get(address) {
+	  if let Some(nonce) = self.cache.nonces.read().get(address) {
 		  return *nonce;
 	  }
 
 	  // We don't check again if cache has been populated.
 	  // It's not THAT expensive to fetch the nonce from state.
-	  let mut cache = self.cache.write();
+	  let mut cache = self.cache.nonces.write();
 	  let nonce = self.client.latest_nonce(address);
 	  cache.insert(*address, nonce);
 
-	  if cache.len() < MAX_NONCE_CACHE_SIZE {
+	  if cache.len() < self.cache.limit {
 		  return nonce
 	  }
 
+	  debug!(target: "txpool", "NonceCache: reached limit.");
+	  trace_time!("nonce_cache:clear");
+
 	  // Remove excessive amount of entries from the cache
-	  while cache.len() > EXPECTED_NONCE_CACHE_SIZE {
-		  // Just remove random entry
-		  if let Some(key) = cache.keys().next().cloned() {
-			  cache.remove(&key);
-		  }
+	  let to_remove: Vec<_> = cache.keys().take(self.cache.limit / 2).cloned().collect();
+	  for x in to_remove {
+		cache.remove(&x);
 	  }
+
 	  nonce
   }
 }
diff --git a/ethcore/sync/src/api.rs b/ethcore/sync/src/api.rs
index 56bc579ad..ef54a4802 100644
--- a/ethcore/sync/src/api.rs
+++ b/ethcore/sync/src/api.rs
@@ -384,7 +384,6 @@ impl NetworkProtocolHandler for SyncProtocolHandler {
 	}
 
 	fn read(&self, io: &NetworkContext, peer: &PeerId, packet_id: u8, data: &[u8]) {
-		trace_time!("sync::read");
 		ChainSync::dispatch_packet(&self.sync, &mut NetSyncIo::new(io, &*self.chain, &*self.snapshot_service, &self.overlay), *peer, packet_id, data);
 	}
 
diff --git a/miner/src/pool/queue.rs b/miner/src/pool/queue.rs
index 40f3840d8..24a56c226 100644
--- a/miner/src/pool/queue.rs
+++ b/miner/src/pool/queue.rs
@@ -43,6 +43,14 @@ type Pool = txpool::Pool<pool::VerifiedTransaction, scoring::NonceAndGasPrice, L
 /// since it only affects transaction Condition.
 const TIMESTAMP_CACHE: u64 = 1000;
 
+/// How many senders at once do we attempt to process while culling.
+///
+/// When running with huge transaction pools, culling can take significant amount of time.
+/// To prevent holding `write()` lock on the pool for this long period, we split the work into
+/// chunks and allow other threads to utilize the pool in the meantime.
+/// This parameter controls how many (best) senders at once will be processed.
+const CULL_SENDERS_CHUNK: usize = 1024;
+
 /// Transaction queue status.
 #[derive(Debug, Clone, PartialEq)]
 pub struct Status {
@@ -398,10 +406,11 @@ impl TransactionQueue {
 	}
 
 	/// Culls all stalled transactions from the pool.
-	pub fn cull<C: client::NonceClient>(
+	pub fn cull<C: client::NonceClient + Clone>(
 		&self,
 		client: C,
 	) {
+		trace_time!("pool::cull");
 		// We don't care about future transactions, so nonce_cap is not important.
 		let nonce_cap = None;
 		// We want to clear stale transactions from the queue as well.
@@ -416,10 +425,19 @@ impl TransactionQueue {
 			current_id.checked_sub(gap)
 		};
 
-		let state_readiness = ready::State::new(client, stale_id, nonce_cap);
-
 		self.recently_rejected.clear();
-		let removed = self.pool.write().cull(None, state_readiness);
+
+		let mut removed = 0;
+		let senders: Vec<_> = {
+			let pool = self.pool.read();
+			let senders = pool.senders().cloned().collect();
+			senders
+		};
+		for chunk in senders.chunks(CULL_SENDERS_CHUNK) {
+			trace_time!("pool::cull::chunk");
+			let state_readiness = ready::State::new(client.clone(), stale_id, nonce_cap);
+			removed += self.pool.write().cull(Some(chunk), state_readiness);
+		}
 		debug!(target: "txqueue", "Removed {} stalled transactions. {}", removed, self.status());
 	}
 
diff --git a/transaction-pool/src/pool.rs b/transaction-pool/src/pool.rs
index 6fa17e1b2..e2fa36c0e 100644
--- a/transaction-pool/src/pool.rs
+++ b/transaction-pool/src/pool.rs
@@ -414,6 +414,11 @@ impl<T, S, L> Pool<T, S, L> where
 			|| self.mem_usage >= self.options.max_mem_usage
 	}
 
+	/// Returns senders ordered by priority of their transactions.
+	pub fn senders(&self) -> impl Iterator<Item=&T::Sender> {
+		self.best_transactions.iter().map(|tx| tx.transaction.sender())
+	}
+
 	/// Returns an iterator of pending (ready) transactions.
 	pub fn pending<R: Ready<T>>(&self, ready: R) -> PendingIterator<T, R, S, L> {
 		PendingIterator {
