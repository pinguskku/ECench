commit 21771aa1a6542783833307168128b024fb994b88
Author: Robert Habermeier <rphmeier@gmail.com>
Date:   Tue Mar 21 20:23:58 2017 +0100

    don't keep headers in memory to avoid DoS

diff --git a/ethcore/light/src/client/header_chain.rs b/ethcore/light/src/client/header_chain.rs
index 676142b17..25c836051 100644
--- a/ethcore/light/src/client/header_chain.rs
+++ b/ethcore/light/src/client/header_chain.rs
@@ -24,7 +24,7 @@
 //!   - It stores only headers (and a pruned subset of them)
 //!   - To allow for flexibility in the database layout once that's incorporated.
 
-use std::collections::{BTreeMap, HashMap};
+use std::collections::BTreeMap;
 use std::sync::Arc;
 
 use cht;
@@ -35,7 +35,7 @@ use ethcore::encoded;
 use ethcore::header::Header;
 use ethcore::ids::BlockId;
 
-use rlp::{Encodable, Decodable, Decoder, DecoderError, RlpStream, View};
+use rlp::{Encodable, Decodable, Decoder, DecoderError, RlpStream, Rlp, View};
 use util::{H256, U256, HeapSizeOf, RwLock};
 use util::kvdb::{DBTransaction, KeyValueDB};
 
@@ -46,8 +46,8 @@ use smallvec::SmallVec;
 /// relevant to any blocks we've got in memory.
 const HISTORY: u64 = 2048;
 
-/// The best block key. Maps to a `u64` best block number.
-const BEST_KEY: &'static [u8] = &*b"best_block_key";
+/// The best block key. Maps to an RLP list: [best_era, last_era]
+const CURRENT_KEY: &'static [u8] = &*b"best_and_latest";
 
 /// Information about a block.
 #[derive(Debug, Clone)]
@@ -131,7 +131,6 @@ fn era_key(number: u64) -> String {
 pub struct HeaderChain {
 	genesis_header: encoded::Header, // special-case the genesis.
 	candidates: RwLock<BTreeMap<u64, Entry>>,
-	headers: RwLock<HashMap<H256, encoded::Header>>,
 	best_block: RwLock<BlockDescriptor>,
 	db: Arc<KeyValueDB>,
 	col: Option<u32>,
@@ -142,30 +141,33 @@ impl HeaderChain {
 	pub fn new(db: Arc<KeyValueDB>, col: Option<u32>, genesis: &[u8]) -> Result<Self, String> {
 		use ethcore::views::HeaderView;
 
-		let chain = if let Some(best_number) = db.get(col, BEST_KEY)?.map(|x| ::rlp::decode(&x)) {
-			let mut cur_number = best_number;
+		let chain = if let Some(current) = db.get(col, CURRENT_KEY)? {
+			let (best_number, highest_number) = {
+				let rlp = Rlp::new(&current);
+				(rlp.val_at(0), rlp.val_at(1))
+			};
+
+			let mut cur_number = highest_number;
 			let mut candidates = BTreeMap::new();
-			let mut headers = HashMap::new();
 
 			// load all era entries and referenced headers within them.
 			while let Some(entry) = db.get(col, era_key(cur_number).as_bytes())? {
 				let entry: Entry = ::rlp::decode(&entry);
-				for candidate in &entry.candidates {
-					match db.get(col, &*candidate.hash)? {
-						Some(hdr) => headers.insert(candidate.hash, encoded::Header::new(hdr.to_vec())),
-						None => return Err(format!("Database missing referenced header: {}", candidate.hash)),
-					};
-				}
+				trace!(target: "chain", "loaded header chain entry for era {} with {} candidates",
+					cur_number, entry.candidates.len());
+
 				candidates.insert(cur_number, entry);
 
 				cur_number -= 1;
 			}
 
 			// fill best block block descriptor.
-			if candidates.is_empty() { return Err(format!("Database corrupt: best block referenced but no data.")) }
 			let best_block = {
-				let era = candidates.get(&best_number)
-					.expect("candidates non-empty; filled in loop starting at best_number; qed");
+				let era = match candidates.get(&best_number) {
+					Some(era) => era,
+					None => return Err(format!("Database corrupt: highest block referenced but no data.")),
+				};
+
 				let best = &era.candidates[0];
 				BlockDescriptor {
 					hash: best.hash,
@@ -178,7 +180,6 @@ impl HeaderChain {
 				genesis_header: encoded::Header::new(genesis.to_owned()),
 				best_block: RwLock::new(best_block),
 				candidates: RwLock::new(candidates),
-				headers: RwLock::new(headers),
 				db: db,
 				col: col,
 			}
@@ -192,7 +193,6 @@ impl HeaderChain {
 					total_difficulty: g_view.difficulty(),
 				}),
 				candidates: RwLock::new(BTreeMap::new()),
-				headers: RwLock::new(HashMap::new()),
 				db: db,
 				col: col,
 			}
@@ -225,7 +225,7 @@ impl HeaderChain {
 
 		let total_difficulty = parent_td + *header.difficulty();
 
-		// insert headers and candidates entries.
+		// insert headers and candidates entries and write era to disk.
 		{
 			let cur_era = candidates.entry(number)
 				.or_insert_with(|| Entry { candidates: SmallVec::new(), canonical_hash: hash });
@@ -234,15 +234,32 @@ impl HeaderChain {
 				parent_hash: parent_hash,
 				total_difficulty: total_difficulty,
 			});
+
+			// fix ordering of era before writing.
+			if total_difficulty > cur_era.candidates[0].total_difficulty {
+				let cur_pos = cur_era.candidates.len() - 1;
+				cur_era.candidates.swap(cur_pos, 0);
+				cur_era.canonical_hash = hash;
+			}
+
+			transaction.put(self.col, era_key(number).as_bytes(), &::rlp::encode(&*cur_era))
 		}
 
 		let raw = ::rlp::encode(&header);
 		transaction.put(self.col, &hash[..], &*raw);
-		self.headers.write().insert(hash, encoded::Header::new(raw.to_vec()));
+
+		let (best_num, is_new_best) = {
+			let cur_best = self.best_block.read();
+			if cur_best.total_difficulty < total_difficulty {
+				(number, true)
+			} else {
+				(cur_best.number, false)
+			}
+		};
 
 		// reorganize ancestors so canonical entries are first in their
 		// respective candidates vectors.
-		if self.best_block.read().total_difficulty < total_difficulty {
+		if is_new_best {
 			let mut canon_hash = hash;
 			for (&height, entry) in candidates.iter_mut().rev().skip_while(|&(height, _)| *height > number) {
 				if height != number && entry.canonical_hash == canon_hash { break; }
@@ -262,9 +279,11 @@ impl HeaderChain {
 				// resetting to the last block of a given CHT should be possible.
 				canon_hash = entry.candidates[0].parent_hash;
 
-				// write altered era to disk.
-				let rlp_era = ::rlp::encode(&*entry);
-				transaction.put(self.col, era_key(height).as_bytes(), &rlp_era);
+				// write altered era to disk
+				if height != number {
+					let rlp_era = ::rlp::encode(&*entry);
+					transaction.put(self.col, era_key(height).as_bytes(), &rlp_era);
+				}
 			}
 
 			trace!(target: "chain", "New best block: ({}, {}), TD {}", number, hash, total_difficulty);
@@ -273,7 +292,6 @@ impl HeaderChain {
 				number: number,
 				total_difficulty: total_difficulty,
 			};
-			transaction.put(self.col, BEST_KEY, &*::rlp::encode(&number));
 
 			// produce next CHT root if it's time.
 			let earliest_era = *candidates.keys().next().expect("at least one era just created; qed");
@@ -281,8 +299,6 @@ impl HeaderChain {
 				let cht_num = cht::block_to_cht_number(earliest_era)
 					.expect("fails only for number == 0; genesis never imported; qed");
 
-				let mut headers = self.headers.write();
-
 				let cht_root = {
 					let mut i = earliest_era;
 
@@ -296,7 +312,6 @@ impl HeaderChain {
 						i += 1;
 
 						for ancient in &era_entry.candidates {
-							headers.remove(&ancient.hash);
 							transaction.delete(self.col, &ancient.hash);
 						}
 
@@ -313,20 +328,37 @@ impl HeaderChain {
 			}
 		}
 
+		// write the best and latest eras to the database.
+		{
+			let latest_num = *candidates.iter().rev().next().expect("at least one era just inserted; qed").0;
+			let mut stream = RlpStream::new_list(2);
+			stream.append(&best_num).append(&latest_num);
+			transaction.put(self.col, CURRENT_KEY, &stream.out())
+		}
 		Ok(())
 	}
 
 	/// Get a block header. In the case of query by number, only canonical blocks
 	/// will be returned.
 	pub fn block_header(&self, id: BlockId) -> Option<encoded::Header> {
+		let load_from_db = |hash: H256| {
+			match self.db.get(self.col, &hash) {
+				Ok(val) => val.map(|x| x.to_vec()).map(encoded::Header::new),
+				Err(e) => {
+					warn!(target: "chain", "Failed to read from database: {}", e);
+					None
+				}
+			}
+		};
+
 		match id {
 			BlockId::Earliest | BlockId::Number(0) => Some(self.genesis_header.clone()),
-			BlockId::Hash(hash) => self.headers.read().get(&hash).cloned(),
+			BlockId::Hash(hash) => load_from_db(hash),
 			BlockId::Number(num) => {
 				if self.best_block.read().number < num { return None }
 
 				self.candidates.read().get(&num).map(|entry| entry.canonical_hash)
-					.and_then(|hash| self.headers.read().get(&hash).cloned())
+					.and_then(load_from_db)
 			}
 			BlockId::Latest | BlockId::Pending => {
 				let hash = {
@@ -338,7 +370,7 @@ impl HeaderChain {
 					best.hash
 				};
 
-				self.headers.read().get(&hash).cloned()
+				load_from_db(hash)
 			}
 		}
 	}
@@ -401,7 +433,7 @@ impl HeaderChain {
 
 	/// Get block status.
 	pub fn status(&self, hash: &H256) -> BlockStatus {
-		match self.headers.read().contains_key(hash) {
+		match self.db.get(self.col, &*hash).ok().map_or(false, |x| x.is_some()) {
 			true => BlockStatus::InChain,
 			false => BlockStatus::Unknown,
 		}
@@ -410,8 +442,7 @@ impl HeaderChain {
 
 impl HeapSizeOf for HeaderChain {
 	fn heap_size_of_children(&self) -> usize {
-		self.candidates.read().heap_size_of_children() +
-			self.headers.read().heap_size_of_children()
+		self.candidates.read().heap_size_of_children()
 	}
 }
 
@@ -603,4 +634,56 @@ mod tests {
 		assert!(chain.cht_root(3).is_none());
 		assert_eq!(chain.block_header(BlockId::Latest).unwrap().number(), 9999);
 	}
+
+	#[test]
+	fn restore_higher_non_canonical() {
+		let spec = Spec::new_test();
+		let genesis_header = spec.genesis_header();
+		let db = make_db();
+
+		{
+			let chain = HeaderChain::new(db.clone(), None, &::rlp::encode(&genesis_header)).unwrap();
+			let mut parent_hash = genesis_header.hash();
+			let mut rolling_timestamp = genesis_header.timestamp();
+
+			// push 100 low-difficulty blocks.
+			for i in 1..101 {
+				let mut header = Header::new();
+				header.set_parent_hash(parent_hash);
+				header.set_number(i);
+				header.set_timestamp(rolling_timestamp);
+				header.set_difficulty(*genesis_header.difficulty() * i.into());
+				parent_hash = header.hash();
+
+				let mut tx = db.transaction();
+				chain.insert(&mut tx, header).unwrap();
+				db.write(tx).unwrap();
+
+				rolling_timestamp += 10;
+			}
+
+			// push fewer high-difficulty blocks.
+			for i in 1..11 {
+				let mut header = Header::new();
+				header.set_parent_hash(parent_hash);
+				header.set_number(i);
+				header.set_timestamp(rolling_timestamp);
+				header.set_difficulty(*genesis_header.difficulty() * i.into() * 1000.into());
+				parent_hash = header.hash();
+
+				let mut tx = db.transaction();
+				chain.insert(&mut tx, header).unwrap();
+				db.write(tx).unwrap();
+
+				rolling_timestamp += 10;
+			}
+
+			assert_eq!(chain.block_header(BlockId::Latest).unwrap().number(), 10);
+		}
+
+		// after restoration, non-canonical eras should still be loaded.
+		let chain = HeaderChain::new(db.clone(), None, &::rlp::encode(&genesis_header)).unwrap();
+		assert_eq!(chain.block_header(BlockId::Latest).unwrap().number(), 10);
+		assert!(chain.candidates.read().get(&100).is_some())
+	}
 }
